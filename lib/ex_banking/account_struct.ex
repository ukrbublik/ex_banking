defmodule ExBanking.Account do
  defstruct [
    :name,
    :currencies
  ]

  @zero_amount 0.0

  def get_balance(account, currency) do
    account
    |> Map.get(:currencies)
    |> Map.get(currency, @zero_amount)
    |> format_balance
  end

  def set_balance(account, new_balance, currency) do
    new_currencies =
      account
      |> Map.get(:currencies)
      |> Map.put(currency, format_balance(new_balance))
    account
      |> Map.put(:currencies, new_currencies)
  end

  # Could use https://github.com/elixirmoney/money here instead, but code would be a bit more complex
  def format_balance(balance), do: Float.floor(balance * 100.0) / 100.0
end
