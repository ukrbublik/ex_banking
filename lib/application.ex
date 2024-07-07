defmodule ExBanking.Application do
  @moduledoc """
  Application for `ExBanking` module
  """

  use Application

  def start(_type, _args) do
    children = [
      ExBanking.RateLimiter,
      ExBanking.AccountsSupervisor,
      {Registry, keys: :unique, name: ExBanking.AccountsRegistry},
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [
      strategy: :one_for_one,
      name: ExBanking.Supervisor
    ]
    Supervisor.start_link(children, opts)
  end
end
