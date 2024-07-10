defmodule ExBanking do
  @moduledoc """
  `ExBanking` module
  """

  alias ExBanking.RateLimiter
  alias ExBanking.AccountsRegistry


  @doc """
  Creates new user in the system.
  New user has zero balance of any currency.
  """
  @spec create_user(user :: String.t) :: :ok | {:error, :wrong_arguments | :user_already_exists}
  def create_user(user)
    when is_binary(user)
  do
    case AccountsRegistry.create_account(user) do
      {:ok, _account} -> :ok
      {:error, reason, _} -> {:error, reason}
    end
  end
  def create_user(_), do: {:error, :wrong_arguments}


  @doc """
  Increases user’s balance in given `currency` by `amount` value.
  Returns `new_balance` of the user in given format.
  """
  @spec deposit(user :: String.t, amount :: number, currency :: String.t) :: {:ok, new_balance :: number} | {:error, :wrong_arguments | :user_does_not_exist | :too_many_requests_to_user}
  def deposit(user, amount, currency)
    when is_binary(user) and is_number(amount) and is_binary(currency) and amount > 0
  do
    RateLimiter.with_rate_limit(user, fn ->
      case AccountsRegistry.deposit(user, amount, currency) do
        {:ok, new_amount} -> {:ok, new_amount}
        {:error, reason, _} -> {:error, reason}
      end
    end)
  end
  def deposit(_, _, _), do: {:error, :wrong_arguments}


  @doc """
  Decreases user’s balance in given `currency` by `amount` value.
  Returns `new_balance` of the user in given format.
  """
  @spec withdraw(user :: String.t, amount :: number, currency :: String.t) :: {:ok, new_balance :: number} | {:error, :wrong_arguments | :user_does_not_exist | :not_enough_money | :too_many_requests_to_user}
  def withdraw(user, amount, currency)
    when is_binary(user) and is_number(amount) and is_binary(currency) and amount > 0
  do
    RateLimiter.with_rate_limit(user, fn ->
      case AccountsRegistry.withdraw(user, amount, currency) do
        {:ok, new_amount} -> {:ok, new_amount}
        {:error, reason, _} -> {:error, reason}
      end
    end)
  end
  def withdraw(_, _, _), do: {:error, :wrong_arguments}


  @doc """
  Returns `balance` of the user in given format.
  """
  @spec get_balance(user :: String.t, currency :: String.t) :: {:ok, balance :: number} | {:error, :wrong_arguments | :user_does_not_exist | :too_many_requests_to_user}
  def get_balance(user, currency)
    when is_binary(user) and is_binary(currency)
  do
    RateLimiter.with_rate_limit(user, fn ->
      case AccountsRegistry.get_balance(user, currency) do
        {:ok, new_amount} -> {:ok, new_amount}
        {:error, reason, _} -> {:error, reason}
      end
    end)
  end
  def get_balance(_, _), do: {:error, :wrong_arguments}


  @doc """
  Decreases `from_user`’s balance in given `currency` by `amount` value.
  Increases `to_user`’s balance in given `currency` by `amount` value.
  Returns `balance` of `from_user` and `to_user` in given format.
  """
  @spec send(from_user :: String.t, to_user :: String.t, amount :: number, currency :: String.t) ::
    {:ok, from_user_balance :: number, to_user_balance :: number}
    | {:error, :wrong_arguments | :not_enough_money | :sender_does_not_exist | :receiver_does_not_exist | :too_many_requests_to_sender | :too_many_requests_to_receiver}
  def send(from_user, to_user, amount, currency)
    when is_binary(from_user) and is_binary(to_user) and is_number(amount) and is_binary(currency) and amount > 0 and from_user != to_user
  do
    RateLimiter.with_rate_limit(from_user, to_user, fn ->
      with {:ok, sender_amount} <- AccountsRegistry.get_balance(from_user, currency),
        {:amount_check, true} <- {:amount_check, sender_amount >= amount},
        {:ok, new_sender_amount, new_receiver_amount} <- AccountsRegistry.send(from_user, to_user, amount, currency)
      do
        {:ok, new_sender_amount, new_receiver_amount}
      else
        {:error, :user_does_not_exist, user} when user == from_user ->
          {:error, :sender_does_not_exist}
        {:error, :user_does_not_exist, user} when user == to_user ->
          {:error, :receiver_does_not_exist}
        {:amount_check, false} ->
          {:error, :not_enough_money}
        {:error, reason, _user} ->
          {:error, reason}
      end
    end)
  end
  def send(_, _, _, _), do: {:error, :wrong_arguments}


end
