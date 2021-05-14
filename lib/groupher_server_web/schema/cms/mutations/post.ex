defmodule GroupherServerWeb.Schema.CMS.Mutations.Post do
  @moduledoc """
  CMS mutations for post
  """
  use Helper.GqlSchemaSuite

  import GroupherServerWeb.Schema.Helper.Mutations

  object :cms_post_mutations do
    @desc "create a post"
    field :create_post, :post do
      arg(:title, non_null(:string))
      arg(:body, non_null(:string))
      arg(:digest, non_null(:string))
      arg(:length, non_null(:integer))
      arg(:link_addr, :string)
      arg(:copy_right, :string)
      arg(:community_id, non_null(:id))
      arg(:thread, :thread, default_value: :post)
      arg(:tags, list_of(:ids))
      arg(:mention_users, list_of(:ids))

      middleware(M.Authorize, :login)
      # middleware(M.PublishThrottle)
      middleware(M.PublishThrottle, interval: 3, hour_limit: 15, day_limit: 30)
      resolve(&R.CMS.create_article/3)
      middleware(M.Statistics.MakeContribute, for: [:user, :community])
    end

    @desc "update a cms/post"
    field :update_post, :post do
      arg(:id, non_null(:id))
      arg(:title, :string)
      arg(:body, :string)
      arg(:digest, :string)
      arg(:copy_right, :string)
      arg(:link_addr, :string)
      arg(:tags, list_of(:ids))

      middleware(M.Authorize, :login)
      middleware(M.PassportLoader, source: :post)
      middleware(M.Passport, claim: "owner;cms->c?->post.edit")

      resolve(&R.CMS.update_article/3)
    end

    #############
    article_upvote_mutation(:post)
    article_pin_mutation(:post)
    article_trash_mutation(:post)
    article_delete_mutation(:post)
    article_emotion_mutation(:post)
    article_report_mutation(:post)
    #############
  end
end
