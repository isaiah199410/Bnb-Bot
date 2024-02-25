defmodule Adjutant.Repo.CustomQuery do
  @moduledoc """
  Defines custom query methods, this is specific to postgres.
  """

  defmacro array_contains(array, value) do
    quote do
      fragment("? = ANY(?)", unquote(value), unquote(array))
    end
  end

  defmacro word_similarity(column, word) do
    quote do
      fragment("word_similarity(?, ?)", unquote(column), unquote(word))
    end
  end

  defmacro blight_elem_access(column) do
    quote do
      fragment("(?).elem", unquote(column))
    end
  end

  defmacro dienum_access(column) do
    quote do
      fragment("(?).dienum", unquote(column))
    end
  end

  defmacro dietype_access(column) do
    quote do
      fragment("(?).dietype", unquote(column))
    end
  end

  defmacro die_average(column) do
    quote do
      fragment("die_average(?)", unquote(column))
    end
  end
end
