defmodule ExBanking.AccountManager do
  @moduledoc """
    Agent for managing user's account state.
    Started from AccountsRegistry.
  """

  use Agent

  require Logger
  alias ExBanking.Account
  alias ExBanking.AccountsRegistry

  @empty_account %Account{currencies: %{}}

  def start_link({user}) do
    account = Map.merge(@empty_account, %{name: user})
    via_name = {:via, Registry, {AccountsRegistry, user}}
    {:ok, _} = Agent.start_link(fn -> account end, name: via_name)
  end

  def get_account(user) do
    via_name = {:via, Registry, {AccountsRegistry, user}}
    delay = Application.get_env(:ex_banking, :account_crud_delay, 0)
    Process.sleep(delay)
    Agent.get(via_name, & &1)
  end

  def update_account(user, upd_account_fn) do
    via_name = {:via, Registry, {AccountsRegistry, user}}
    delay = Application.get_env(:ex_banking, :account_crud_delay, 0)
    Process.sleep(delay)
    Agent.get_and_update(via_name, fn account ->
      case upd_account_fn.(account) do
        {:ok, new_account} ->
          #Logger.debug("Changing account #{user}: #{inspect account} -> #{inspect new_account}")
          {{:ok, new_account}, new_account}
        {:error, reason} ->
          #Logger.debug("Can't change account #{user}: #{inspect account}: #{inspect reason}")
          {{:error, reason}, account}
      end
    end)
  end


end
