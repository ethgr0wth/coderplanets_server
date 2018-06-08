defmodule MastaniServer.CMS.Delegate.PassportCURD do
  import Helper.Utils, only: [done: 1, deep_merge: 2]
  import Ecto.Query, warn: false
  import ShortMaps

  alias MastaniServer.CMS.Passport, as: UserPasport
  alias MastaniServer.{Repo, Accounts}
  alias Helper.{ORM, NestedFilter}

  # https://medium.com/front-end-hacking/use-github-oauth-as-your-sso-seamlessly-with-react-3e2e3b358fa1
  # http://www.ubazu.com/using-postgres-jsonb-columns-in-ecto
  # http://www.ubazu.com/using-postgres-jsonb-columns-in-ecto

  def list_passports(community, key) do
    UserPasport
    |> where([p], fragment("(?->?->>?)::boolean = ?", p.rules, ^community, ^key, true))
    |> Repo.all()
    |> done
  end

  @doc """
  return a user's passport in CMS context
  """
  def get_passport(%Accounts.User{} = user) do
    with {:ok, passport} <- ORM.find_by(UserPasport, user_id: user.id) do
      {:ok, passport.rules}
    end
  end

  # TODO passport should be public utils
  @doc """
  insert or update a user's passport in CMS context
  """
  def stamp_passport(%Accounts.User{id: user_id}, rules) do
    case ORM.find_by(UserPasport, user_id: user_id) do
      {:ok, passport} ->
        rules = deep_merge(passport.rules, rules) |> reject_invalid_rules
        passport |> ORM.update(~m(rules)a)

      {:error, _} ->
        rules = rules |> reject_invalid_rules
        UserPasport |> ORM.create(~m(user_id rules)a)
    end
  end

  def erase_passport(%Accounts.User{id: user_id}, rules) when is_list(rules) do
    with {:ok, passport} <- ORM.find_by(UserPasport, user_id: user_id) do
      case pop_in(passport.rules, rules) do
        {nil, _} ->
          {:error, "#{rules} not found"}

        {_, lefts} ->
          passport |> ORM.update(%{rules: lefts})
      end
    end
  end

  def delete_passport(%Accounts.User{id: user_id}) do
    ORM.findby_delete(UserPasport, ~m(user_id)a)
  end

  defp reject_invalid_rules(rules) when is_map(rules) do
    rules |> NestedFilter.drop_by_value([false]) |> reject_empty_values
  end

  defp reject_empty_values(map) when is_map(map) do
    for {k, v} <- map, v != %{}, into: %{}, do: {k, v}
  end
end
