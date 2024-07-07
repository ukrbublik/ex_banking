defmodule ExBanking.Account do
  defstruct [
    :name,
    :currencies
  ]

  def get_balance(account, currency) do
    account
    |> Map.get(:currencies)
    |> Map.get(currency, 0.0)
  end

  def set_balance(account, new_balance, currency) do
    new_currencies =
      account
      |> Map.get(:currencies)
      |> Map.put(currency, new_balance)
    account
      |> Map.put(:currencies, new_currencies)
  end
end
