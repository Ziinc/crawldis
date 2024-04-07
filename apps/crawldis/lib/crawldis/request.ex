defmodule Crawldis.Request do
  @moduledoc false
  defstruct id: nil,
            crawl_job_id: nil,
            url: nil,
            headers: [],
            prev_response: nil,
            options: [],
            middlewares: [],
            retries: 0,
            fetcher: nil,
            # applied on each artifact
            extract: nil,
            extracted_data: nil,
            # applied on each artifact
            follow_link_extractors: [],
            follow_links: nil,
            response: nil

  @type header() :: {String.t(), String.t()}
  @type option :: {atom(), String.t()}

  @type module_opts :: {module(), [any()]} | module()
  @type t :: %__MODULE__{
          id: String.t(),
          crawl_job_id: String.t() | nil,
          url: String.t(),
          headers: [header()],
          prev_response: nil,
          options: [option()],
          middlewares: [atom()],
          retries: non_neg_integer(),
          fetcher: module_opts(),
          extract: map(),
          extracted_data: [],
          response: Crawldis.Response.t() | nil
        }

  @doc """
  Create new Crawldis.Request from url, headers and options
  """
  @spec new(url, headers, options) :: request
        when url: binary(),
             headers: [term()],
             options: [term()],
             request: Crawldis.Request.t()

  def new(url, headers \\ [], options \\ []) do
    middlewares = []

    new(url, headers, options, middlewares)
  end

  @doc """
  Same as Crawldis.Request.new/3 from but allows to specify middlewares as the 4th
  parameter.
  """
  @spec new(url, headers, options, middlewares) :: request
        when url: binary(),
             headers: [term()],
             options: [term()],
             middlewares: [term()],
             request: Crawldis.Request.t()
  def new(url, headers, options, middlewares) do
    %Crawldis.Request{
      url: url,
      headers: headers,
      options: options,
      middlewares: middlewares
    }
  end
end
