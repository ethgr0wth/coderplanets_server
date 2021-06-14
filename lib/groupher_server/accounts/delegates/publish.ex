defmodule GroupherServer.Accounts.Delegate.Publish do
  @moduledoc """
  user followers / following related
  """
  import Ecto.Query, warn: false
  import Helper.Utils, only: [done: 1, ensure: 2]
  # import Helper.ErrorCode
  import ShortMaps

  import GroupherServer.CMS.Helper.Matcher

  alias GroupherServer.Accounts.Model.{Embeds, User}
  alias GroupherServer.CMS.Model.Comment

  alias Helper.{ORM, QueryBuilder}

  @default_meta Embeds.UserMeta.default_meta()

  @doc """
  get paged published contets of a user
  """
  def paged_published_articles(%User{id: user_id}, thread, filter) do
    with {:ok, info} <- match(thread),
         {:ok, user} <- ORM.find(User, user_id) do
      do_paged_published_articles(info.model, user, filter)
    end
  end

  @doc """
  update published articles count in user meta
  """
  def update_published_states(user_id, thread) do
    filter = %{page: 1, size: 1}

    with {:ok, info} <- match(thread),
         {:ok, user} <- ORM.find(User, user_id),
         {:ok, paged_published_articles} <- do_paged_published_articles(info.model, user, filter) do
      articles_count = paged_published_articles.total_count

      meta =
        ensure(user.meta, @default_meta) |> Map.put(:"published_#{thread}s_count", articles_count)

      ORM.update_meta(user, meta)
    end
  end

  defp do_paged_published_articles(queryable, %User{} = user, %{page: page, size: size} = filter) do
    queryable
    |> join(:inner, [article], author in assoc(article, :author))
    |> where([article, author], author.user_id == ^user.id)
    |> select([article, author], article)
    |> QueryBuilder.filter_pack(filter)
    |> ORM.paginater(~m(page size)a)
    |> done()
  end

  def paged_published_article_comments(%User{id: user_id}, %{page: page, size: size} = filter) do
    with {:ok, user} <- ORM.find(User, user_id) do
      Comment
      |> join(:inner, [comment], author in assoc(comment, :author))
      |> where([comment, author], author.id == ^user.id)
      |> QueryBuilder.filter_pack(filter)
      |> ORM.paginater(~m(page size)a)
      |> ORM.extract_and_assign_article()
      |> done()
    end
  end

  def paged_published_article_comments(
        %User{id: user_id},
        thread,
        %{page: page, size: size} = filter
      ) do
    with {:ok, user} <- ORM.find(User, user_id) do
      thread = thread |> to_string |> String.upcase()
      thread_atom = thread |> String.downcase() |> String.to_atom()

      article_preload = Keyword.new([{thread_atom, [author: :user]}])
      query = from(comment in Comment, preload: ^article_preload)

      query
      |> join(:inner, [comment], author in assoc(comment, :author))
      |> where([comment, author], author.id == ^user.id)
      |> where([comment, author], comment.thread == ^thread)
      |> QueryBuilder.filter_pack(filter)
      |> ORM.paginater(~m(page size)a)
      |> ORM.extract_and_assign_article()
      |> done()
    end
  end
end
