defmodule GroupherServer.CMS.ArticlePinnedComment do
  @moduledoc false
  alias __MODULE__

  use Ecto.Schema
  use Accessible

  import Ecto.Changeset

  alias GroupherServer.CMS
  alias CMS.ArticleComment

  # alias Helper.HTML

  @required_fields ~w(article_comment_id)a
  @optional_fields ~w(post_id job_id repo_id)a

  @type t :: %ArticlePinnedComment{}
  schema "articles_pinned_comments" do
    belongs_to(:article_comment, ArticleComment, foreign_key: :article_comment_id)
    belongs_to(:post, CMS.Post, foreign_key: :post_id)
    belongs_to(:job, CMS.Job, foreign_key: :job_id)
    belongs_to(:repo, CMS.Repo, foreign_key: :repo_id)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(%ArticlePinnedComment{} = article_pined_comment, attrs) do
    article_pined_comment
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
  end

  # @doc false
  def update_changeset(%ArticlePinnedComment{} = article_pined_comment, attrs) do
    article_pined_comment
    |> cast(attrs, @required_fields ++ @optional_fields)
  end
end
