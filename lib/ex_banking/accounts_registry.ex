defmodule ExBanking.AccountsRegistry do
  @moduledoc """
    Uses Registry as KV storage.
    Starts AccountManager for every user.
  """

  #tip: Error tuple has `user` as last element, needed for distinguishing sender and receiver

  require Logger
  alias ExBanking.Account
  alias ExBanking.AccountManager
  alias ExBanking.AccountsSupervisor

  # Public

  def get_balance(user, currency) do
    case get_account(user) do
      {:ok, account} ->
        {:ok, Account.get_balance(account, currency)}
      {:error, reason, _} ->
        {:error, reason, user}
    end
  end

  def create_account(user) do
    if account_exists?(user) do
      {:error, :user_already_exists, user}
    else
      case start_account(user) do
        :ok ->
          {:ok, AccountManager.get_account(user)}
        error -> error
      end
    end
  end

  def deposit(user, amount, currency) do
    change_amount(user, fn (balance) -> (balance + Account.format_balance(amount)) end, currency)
  end

  def withdraw(user, amount, currency) do
    change_amount(user, fn (balance) -> (balance - Account.format_balance(amount)) end, currency)
  end

  def send(sender, receiver, amount, currency) do
    #TODO: don't need to use mutex? https://hexdocs.pm/mutex/readme.html
    with {:ok, new_sender_amount}
        <- change_amount(sender, fn (balance) -> (balance - Account.format_balance(amount)) end, currency),
      {:ok, new_receiver_amount}
        <- change_amount(receiver, fn (balance) -> (balance + Account.format_balance(amount)) end, currency)
    do
      {:ok, new_sender_amount, new_receiver_amount}
    else
      error -> error
    end
  end


  # Private

  defp get_account(user) do
    if account_exists?(user) do
      {:ok, AccountManager.get_account(user)}
    else
      {:error, :user_does_not_exist, user}
    end
  end

  defp account_exists?(user) do
    case Registry.lookup(__MODULE__, user) do
      [{_, _initial_val}] -> true
      [] -> false
    end
  end

  defp start_account(user) do
    if account_exists?(user) do
      {:error, :user_already_exists, user}
    else
      #Logger.debug("Starting account for #{user}")
      start_res = DynamicSupervisor.start_child(
        AccountsSupervisor, {AccountManager, {user}}
      )
      case start_res do
        {:ok, _} -> :ok
        {:ok, _, _} -> :ok
        {:error, reason} -> {:error, reason, user}
      end
    end
  end

  defp update_account(user, upd_account_fn) do
    if account_exists?(user) do
      AccountManager.update_account(user, upd_account_fn)
    else
      {:error, :user_does_not_exist}
    end
  end

  defp change_amount(user, upd_amount_fn, currency) do
    upd_account_fn = fn account ->
      balance = Account.get_balance(account, currency)
      new_balance = upd_amount_fn.(balance)
      if new_balance >= 0 do
        {:ok, Account.set_balance(account, new_balance, currency)}
      else
        {:error, :not_enough_money}
      end
    end

    case update_account(user, upd_account_fn) do
      {:ok, new_account} ->
        new_balance = new_account |> Account.get_balance(currency)
        {:ok, new_balance}
      {:error, reason} ->
        {:error, reason, user}
    end
  end

end
