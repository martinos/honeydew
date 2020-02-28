defmodule Honeydew.Queue.Mnesia.WrappedJob do
  alias Honeydew.Job

  @record_name :wrapped_job
  @record_fields [:key, :job]

  job_filter_map =
    %Job{}
    |> Map.from_struct()
    |> Enum.map(fn {k, _} ->
      {k, :_}
    end)

  @job_filter struct(Job, job_filter_map)

  defstruct [:run_at, :id, :job]

  def record_name, do: @record_name
  def record_fields, do: @record_fields

  def new(%Job{} = job) do
    id = :erlang.unique_integer()

    job = %{job | private: id}

    %__MODULE__{id: id, job: job}
    |> reset_run_at()
  end

  def from_record({@record_name, {run_at, id}, job}) do
    %__MODULE__{run_at: run_at, id: id, job: job}
  end

  def to_record(%__MODULE__{run_at: run_at, id: id, job: job}) do
    {@record_name, key(run_at, id), job}
  end

  def key({@record_name, key, _job}) do
    key
  end

  def key(run_at, id) do
    {run_at, id}
  end

  def id_from_key({_run_at, id}) do
    id
  end

  def reset_run_at(
        %__MODULE__{job: %Job{delay_secs: delay_secs, enqueued_at: enqueued_at}} = wrapped_job
      ) do
    elapsed = System.system_time(:millisecond) - (enqueued_at + delay_secs * 1_000)
    new_delay = if elapsed >= 0, do: elapsed, else: 0
    run_at = now() + delay_secs

    %__MODULE__{wrapped_job | run_at: run_at}
  end

  def id_pattern(id) do
    %__MODULE__{
      id: id,
      run_at: :_,
      job: :_
    }
    |> to_record
  end

  def filter_pattern(map) do
    job = struct(@job_filter, map)

    %__MODULE__{
      id: :_,
      run_at: :_,
      job: job
    }
    |> to_record
  end

  def reserve_match_spec do
    pattern =
      %__MODULE__{
        id: :_,
        run_at: :"$1",
        job: :_
      }
      |> to_record

    [
      {
        pattern,
        [{:"=<", :"$1", now()}],
        [:"$_"]
      }
    ]
  end

  defp now do
    :erlang.monotonic_time(:second)
  end
end
