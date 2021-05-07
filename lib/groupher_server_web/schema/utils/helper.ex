defmodule GroupherServerWeb.Schema.Utils.Helper do
  @moduledoc """
  common fields
  """
  import Helper.Utils, only: [get_config: 2]

  alias GroupherServer.{Accounts, CMS}
  alias CMS.{ArticleComment}

  @page_size get_config(:general, :page_size)
  @supported_emotions ArticleComment.supported_emotions()
  @supported_collect_folder_threads Accounts.CollectFolder.supported_threads()

  defmacro timestamp_fields do
    quote do
      field(:inserted_at, :datetime)
      field(:updated_at, :datetime)
    end
  end

  # see: https://github.com/absinthe-graphql/absinthe/issues/363
  defmacro pagination_args do
    quote do
      field(:page, :integer, default_value: 1)
      field(:size, :integer, default_value: unquote(@page_size))
    end
  end

  defmacro pagination_fields do
    quote do
      field(:total_count, :integer)
      field(:page_size, :integer)
      field(:total_pages, :integer)
      field(:page_number, :integer)
    end
  end

  defmacro article_filter_fields do
    quote do
      field(:when, :when_enum)
      field(:length, :length_enum)
      field(:tag, :string, default_value: :all)
      field(:community, :string)
    end
  end

  defmacro social_fields do
    quote do
      field(:qq, :string)
      field(:weibo, :string)
      field(:weichat, :string)
      field(:github, :string)
      field(:zhihu, :string)
      field(:douban, :string)
      field(:twitter, :string)
      field(:facebook, :string)
      field(:dribble, :string)
      field(:instagram, :string)
      field(:pinterest, :string)
      field(:huaban, :string)
    end
  end

  import Absinthe.Resolution.Helpers, only: [dataloader: 2]

  alias GroupherServer.CMS
  alias GroupherServerWeb.Middleware, as: M
  alias GroupherServerWeb.Resolvers, as: R

  # Big thanks: https://elixirforum.com/t/grouping-error-in-absinthe-dadaloader/13671/2
  # see also: https://github.com/absinthe-graphql/dataloader/issues/25
  defmacro content_counts_field(thread, schema) do
    quote do
      field unquote(String.to_atom("#{to_string(thread)}s_count")), :integer do
        resolve(fn community, _args, %{context: %{loader: loader}} ->
          loader
          |> Dataloader.load(CMS, {:one, unquote(schema)}, [
            {unquote(String.to_atom("#{to_string(thread)}s_count")), community.id}
          ])
          |> on_load(fn loader ->
            {:ok,
             Dataloader.get(loader, CMS, {:one, unquote(schema)}, [
               {unquote(String.to_atom("#{to_string(thread)}s_count")), community.id}
             ])}
          end)
        end)
      end
    end
  end

  defmacro viewer_has_state_fields do
    quote do
      field(:viewer_has_collected, :boolean)
      field(:viewer_has_upvoted, :boolean)
      field(:viewer_has_viewed, :boolean)
      field(:viewer_has_reported, :boolean)
    end
  end

  @doc """
  query generator for threads, like:

  post, page_posts ...
  """
  defmacro article_queries(thread) do
    quote do
      @desc unquote("get #{thread} by id")
      field unquote(thread), non_null(unquote(thread)) do
        arg(:id, non_null(:id))
        arg(:thread, unquote(:"#{thread}_thread"), default_value: unquote(thread))

        resolve(&R.CMS.read_article/3)
      end

      @desc unquote("get paged #{thread}s")
      field unquote(:"paged_#{thread}s"), unquote(:"paged_#{thread}s") do
        arg(:thread, unquote(:"#{thread}_thread"), default_value: unquote(thread))
        arg(:filter, non_null(unquote(:"paged_#{thread}s_filter")))

        middleware(M.PageSizeProof)
        resolve(&R.CMS.paged_articles/3)
      end
    end
  end

  defmacro article_reacted_users_query(action, resolver) do
    quote do
      @desc unquote("get paged #{action}ed users of an article")
      field unquote(:"#{action}ed_users"), :paged_users do
        arg(:id, non_null(:id))
        arg(:thread, :cms_thread, default_value: :post)
        arg(:filter, non_null(:paged_filter))

        middleware(M.PageSizeProof)
        resolve(unquote(resolver))
      end
    end
  end

  defmacro comments_fields do
    quote do
      field(:id, :id)
      field(:body, :string)
      field(:floor, :integer)
      field(:author, :user, resolve: dataloader(CMS, :author))

      field :reply_to, :comment do
        resolve(dataloader(CMS, :reply_to))
      end

      field :likes, list_of(:user) do
        arg(:filter, :members_filter)

        middleware(M.PageSizeProof)
        resolve(dataloader(CMS, :likes))
      end

      field :likes_count, :integer do
        arg(:count, :count_type, default_value: :count)

        resolve(dataloader(CMS, :likes))
        middleware(M.ConvertToInt)
      end

      field :viewer_has_liked, :boolean do
        arg(:viewer_did, :viewer_did_type, default_value: :viewer_did)

        middleware(M.Authorize, :login)
        # put current user into dataloader's args
        middleware(M.PutCurrentUser)
        resolve(dataloader(CMS, :likes))
        middleware(M.ViewerDidConvert)
      end

      field :replies, list_of(:comment) do
        arg(:filter, :members_filter)

        middleware(M.ForceLoader)
        middleware(M.PageSizeProof)
        resolve(dataloader(CMS, :replies))
      end

      field :replies_count, :integer do
        arg(:count, :count_type, default_value: :count)

        resolve(dataloader(CMS, :replies))
        middleware(M.ConvertToInt)
      end

      timestamp_fields()
    end
  end

  defmacro comments_counter_fields(thread) do
    quote do
      # @dec "total comments of the post"
      field :comments_count, :integer do
        arg(:count, :count_type, default_value: :count)

        resolve(dataloader(CMS, :comments))
        middleware(M.ConvertToInt)
      end

      # @desc "unique participator list of a the comments"
      field :comments_participators, list_of(:user) do
        arg(:filter, :members_filter)
        arg(:unique, :unique_type, default_value: true)

        # middleware(M.ForceLoader)
        middleware(M.PageSizeProof)
        resolve(dataloader(CMS, :comments))
        middleware(M.CutParticipators)
      end

      field(:paged_comments_participators, :paged_users) do
        arg(
          :thread,
          unquote(String.to_atom("#{to_string(thread)}_thread")),
          default_value: unquote(thread)
        )

        resolve(&R.CMS.paged_comments_participators/3)
      end
    end
  end

  @doc """
  general emotions for comments
  #NOTE: xxx_user_logins field is not support for gq-endpoint
  """
  defmacro emotion_fields() do
    @supported_emotions
    |> Enum.map(fn emotion ->
      quote do
        field(unquote(:"#{emotion}_count"), :integer)
        field(unquote(:"viewer_has_#{emotion}ed"), :boolean)
        field(unquote(:"latest_#{emotion}_users"), list_of(:simple_user))
      end
    end)
  end

  @doc """
  general collect folder meta info
  """
  defmacro collect_folder_meta_fields() do
    @supported_collect_folder_threads
    |> Enum.map(fn thread ->
      quote do
        field(unquote(:"has_#{thread}"), :boolean)
        field(unquote(:"#{thread}_count"), :integer)
      end
    end)
  end
end
