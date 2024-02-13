defmodule Crawldis.RequestQueue do
  @moduledoc false
  alias Crawldis.RequestQueue
  alias Crawldis.Syncer
  alias Crawldis.RequestQueue.Worker
  require Logger
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, [])
  end

  @impl true
  def init(_init_arg) do
    children = [
      Worker,
      {Syncer,
       name: __MODULE__.Syncer,
       get_pid: fn ->
         Map.get(get_state(), :crdt_pid)
       end}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @type item_status :: :unclaimed | :claimed

  @type t :: %RequestQueue{
          crdt_pid: pid()
        }
  defmodule Meta do
  @moduledoc false

    defstruct claimed_datetime: nil,
              request: nil,
              status: :unclaimed
  end

  @type queue_item :: %Meta{}
  defstruct crdt_pid: nil
  require Logger

  # API

  @spec get_state() :: __MODULE__.Worker.t()
  def get_state() do
    GenServer.call(Worker, :state)
  end

  @spec add_request(Crawldis.Request.t()) :: :ok
  def add_request(request) do
    GenServer.cast(Worker, {:add_request, request})
  end

  @spec claim_request() :: :ok
  def claim_request() do
    GenServer.cast(Worker, :claim_request)
  end

  @spec clear_requests() :: :ok
  def clear_requests() do
    GenServer.call(Worker, :clear_requests)
  end

  @spec clear_requests_by_crawl_job_id(String.t() | [String.t()]) :: :ok
  def clear_requests_by_crawl_job_id(crawl_job_id) do
    GenServer.call(Worker, {:clear_requests, :crawl_job_id, crawl_job_id})
  end

  @spec pop_claimed_request() ::
          {:ok, Crawldis.Request.t()} | {:error, :queue_empty | :no_claimed}
  def pop_claimed_request() do
    GenServer.call(Worker, :pop_claimed_request)
  end

  @spec count_requests() :: integer()
  @spec count_requests(:all | item_status()) :: integer()
  def count_requests(filter \\ :all) do
    GenServer.call(Worker, {:count_requests, filter})
  end

  @spec list_requests() :: [Crawldis.Request.t()]
  @spec list_requests(:all | item_status()) :: [Crawldis.Request.t()]
  def list_requests(filter \\ :all) do
    GenServer.call(Worker, {:list_requests, filter})
  end

  @doc false
  @spec get_state :: RequestQueue.t()
  def get_state do
    GenServer.call(Worker, :state)
  end
end