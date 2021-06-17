defmodule Cldr.CurencyNotSavedError do
  @moduledoc """
  Exception raised when an attempt is save a new currency
  to the ETS table is not successful.
  """
  defexception [:message]

  def exception(message) do
    %__MODULE__{message: message}
  end
end
