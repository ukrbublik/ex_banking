defmodule ExBanking.RateLimiter do
  @moduledoc """
    GenServer for rate limiting of requests
  """

  use GenServer
  require Logger

  # Client

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(_) do
    initial_state = %{requests: %{}}
    {:ok, initial_state}
  end

  def start_request(user) do
    GenServer.call(__MODULE__, {:start_request, user, user})
  end

  def start_request(user1, user2) do
    GenServer.call(__MODULE__, {:start_request, user1, user2})
  end

  def end_request(user) do
    GenServer.cast(__MODULE__, {:end_request, user})
  end

  def end_request(user1, user2) do
    GenServer.cast(__MODULE__, {:end_request, user1})
    GenServer.cast(__MODULE__, {:end_request, user2})
  end

  # Server

  @impl true
  def handle_call({:start_request, user1, user2}, _from, state) do
    max_requests = Application.get_env(:ex_banking, :max_requests, 10)
    user1_requests = state.requests |> Map.get(user1, 0)
    user2_requests = state.requests |> Map.get(user2, 0)
    cond do
      user1_requests >= max_requests ->
        {:reply, {:error, :too_many_requests_to_user, user1}, state}
      user2_requests >= max_requests ->
        {:reply, {:error, :too_many_requests_to_user, user2}, state}
      true ->
        new_state = state
          |> put_in([:requests, user1], user1_requests + 1)
          |> put_in([:requests, user2], user2_requests + 1)
        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_cast({:end_request, user}, state) do
    case state.requests[user] do
      count when not is_nil(count) and count > 0 ->
        new_count = count - 1
        new_state = if new_count > 0 do
          state |> put_in([:requests, user], new_count)
        else
          {_, new_state} = state |> pop_in([:requests, user])
          new_state
        end
        {:noreply, new_state}
      _ ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(_, state),
    do: {:noreply, state}

end
