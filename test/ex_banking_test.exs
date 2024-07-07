defmodule ExBankingTest do
  use ExUnit.Case
  require Logger
  alias ExBanking

  test ":wrong_arguments" do
    {:error, :wrong_arguments} = ExBanking.create_user(nil)
    {:error, :wrong_arguments} = ExBanking.deposit("some_user", -10, "MDL")
    {:error, :wrong_arguments} = ExBanking.deposit("some_user", 10, nil)
    {:error, :wrong_arguments} = ExBanking.deposit("some_user", "10", "MDL")
    {:error, :wrong_arguments} = ExBanking.get_balance("some_user", nil)
    {:error, :wrong_arguments} = ExBanking.get_balance(nil, "MDL")
    {:error, :wrong_arguments} = ExBanking.send("some_user", "another_user", 10, ~c"MDL")
    {:error, :wrong_arguments} = ExBanking.send("some_user", "some_user", 10, "MDL")
    {:error, :wrong_arguments} = ExBanking.send("some_user", "another_user", nil, "MDL")
    {:error, :wrong_arguments} = ExBanking.send("some_user", "another_user", 10, nil)
    {:error, :wrong_arguments} = ExBanking.send("some_user", "another_user", 0, "MDL")
    {:error, :wrong_arguments} = ExBanking.send("some_user", "another_user", -10, "MDL")
    {:error, :wrong_arguments} = ExBanking.send("some_user", nil, 10, "MDL")
    {:error, :wrong_arguments} = ExBanking.send(nil, "some_user", 10, "MDL")
  end

  test ":user_does_not_exist" do
    :ok = ExBanking.create_user("from")
    {:ok, 10.0} = ExBanking.deposit("from", 10, "MDL")
    {:error, :user_does_not_exist} = ExBanking.deposit("some_user", 10, "MDL")
    {:error, :user_does_not_exist} = ExBanking.withdraw("some_user", 10, "MDL")
    {:error, :user_does_not_exist} = ExBanking.get_balance("some_user", "MDL")
    {:error, :sender_does_not_exist} = ExBanking.send("not_exists", "to", 10, "MDL")
    {:error, :receiver_does_not_exist} = ExBanking.send("from", "to", 10, "MDL")
  end


  test "create_user" do
    user = "Dmitry"
    :ok = ExBanking.create_user(user)
  end

  test ":user_already_exists" do
    user = "Anton"
    :ok = ExBanking.create_user(user)
    {:error, :user_already_exists} = ExBanking.create_user(user)
  end

  test "deposit and get_balance" do
    user = "Valentin"
    currency = "MDL"
    currency2 = "RON"
    :ok = ExBanking.create_user(user)
    {:ok, +0.0} = ExBanking.get_balance(user, currency)
    {:ok, 10.0} = ExBanking.deposit(user, 10, currency)
    {:ok, 35.0} = ExBanking.deposit(user, 25, currency)
    {:ok, 35.0} = ExBanking.get_balance(user, currency)
    {:ok, +0.0} = ExBanking.get_balance(user, currency2)
    {:ok, 12.0} = ExBanking.deposit(user, 12, currency2)
    {:ok, 12.0} = ExBanking.get_balance(user, currency2)
  end

  test "withdraw" do
    user = "Alexey"
    currency = "MDL"
    currency2 = "RON"
    :ok = ExBanking.create_user(user)
    {:error, :not_enough_money} = ExBanking.withdraw(user, 10.0, currency)
    {:ok, 10.0} = ExBanking.deposit(user, 10.0, currency)
    {:error, :not_enough_money} = ExBanking.withdraw(user, 20.0, currency)
    {:error, :not_enough_money} = ExBanking.withdraw(user, 20.0, currency2)
    {:ok, 4.50} = ExBanking.withdraw(user, 5.50, currency)
  end

  test "rate limitting for deposit" do
    user = "Denys"
    currency = "MDL"
    :ok = ExBanking.create_user(user)

    # at 1st pass 10 of 30 should be succeeded
    max_requests = Application.get_env(:ex_banking, :max_requests, 10)
    parallel_cnt = max_requests * 2
    {succeeded_cnt_1, _, _} = run_in_parallel(parallel_cnt, fn i -> ExBanking.deposit(user, i, currency) end)
    assert succeeded_cnt_1 < parallel_cnt
    assert succeeded_cnt_1 >= max_requests
    #TODO: succeeded count can be > 10 if config :account_crud_delay is 0
    assert succeeded_cnt_1 == max_requests

    # at 2nd pass all 10 should be succeeded
    {succeeded_cnt_2, _, _} = run_in_parallel(10, fn i -> ExBanking.deposit(user, i, currency) end)
    assert succeeded_cnt_2 == 10
  end

  test "parallel deposit/withdraw" do
    user1 = "Vitaly"
    user2 = "Igor"
    currency = "MDL"
    :ok = ExBanking.create_user(user1)
    :ok = ExBanking.create_user(user2)
    initial_amount = 300.0
    {:ok, initial_amount} = ExBanking.deposit(user1, initial_amount, currency)
    {:ok, initial_amount} = ExBanking.deposit(user2, initial_amount, currency)

    max_requests = Application.get_env(:ex_banking, :max_requests, 10)
    run_in_parallel(max_requests * 2, fn i ->
      case rem(i - 1, 4) do
        0 -> ExBanking.deposit(user1, 10.0, currency)
        1 -> ExBanking.withdraw(user1, 10.0, currency)
        2 -> ExBanking.deposit(user2, 10.0, currency)
        3 -> ExBanking.withdraw(user2, 10.0, currency)
      end
    end)

    {:ok, user1_amount} = ExBanking.get_balance(user1, currency)
    {:ok, user2_amount} = ExBanking.get_balance(user2, currency)
    #Logger.debug "parallel deposit/withdraw: #{user1_amount}/#{user2_amount}"
    assert user1_amount == initial_amount
    assert user2_amount == initial_amount
  end

  test "send stress test" do
    users = ["Ion", "Timofey", "Olga", "Oksana", "Lidia"]
    currency = "MDL"
    initial_amount = 100.0
    send_amount = 10.0
    initial_amounts = users
      |> Enum.map(fn u ->
        :ok = ExBanking.create_user(u)
        {:ok, initial_amount} = ExBanking.deposit(u, initial_amount, currency)
        initial_amount
      end)
    total_amount = Enum.sum(initial_amounts)
    max_requests = Application.get_env(:ex_banking, :max_requests, 10)
    {_, error_reasons, _tasks} = run_in_parallel(max_requests * length(users), fn _i ->
      sender = users |> pick_random([])
      receiver = users |> pick_random([sender])
      ExBanking.send(sender, receiver, send_amount, currency)
    end)

    new_amounts = users
      |> Enum.map(fn u ->
        {:ok, amount} = ExBanking.get_balance(u, currency)
        amount
      end)
    new_total_amount = Enum.sum(new_amounts)
    assert new_total_amount == total_amount

    #Logger.debug "send: from #{inspect initial_amounts} to #{inspect new_amounts}"
    assert error_reasons.too_many_requests_to_sender > 0
    assert error_reasons.too_many_requests_to_receiver > 0
  end

  # Utils

  defp run_in_parallel(cnt, fun) do
    tasks = 1..cnt
    |> Enum.map(fn i ->
      Task.async(fn ->
        { number_to_atom(i), fun.(i) }
      end)
    end)
    tasks_res = tasks |> Task.await_many()
    #Logger.debug "Tasks results: #{inspect tasks_res}"
    succeeded_tasks_cnt = tasks_res |> Enum.count(fn
      {_num, {res_type, _}} -> res_type == :ok
      {_num, {res_type, _, _}} -> res_type == :ok
    end)
    error_reasons = tasks_res
      |> Enum.filter(fn
        {_num, {:error, _reason}} -> true
        _ -> false
      end)
      |> Enum.map(fn
        {_num, {:error, reason}} -> reason
      end)
      |> Enum.frequencies
    {succeeded_tasks_cnt, error_reasons, tasks_res}
  end

  defp string_to_atom(str) do
    try do
      String.to_existing_atom(str)
    rescue
      ArgumentError -> String.to_atom(str)
    end
  end

  defp number_to_atom(num) do
    num
    |> Integer.to_string()
    |> string_to_atom()
  end

  defp pick_random(list, not_in_list) do
    pick = list |> Enum.at(Enum.random(0..length(list)-1))
    cond do
      Enum.member?(not_in_list, pick) ->
        pick_random(list, not_in_list)
      true -> pick
    end
  end
end
