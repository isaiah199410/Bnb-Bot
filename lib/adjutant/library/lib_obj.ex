defprotocol Adjutant.Library.LibObj do
  @doc """
  Return the type of the libobj.
  """
  @spec type(t) :: :ncp | :chip | :virus
  def type(value)

  @doc """
  Return the libobj as a button.
  Custom ID is expected to be in the format of `"(kind)_(lowercase_name)"`.
  Where kind is a single letter that represents the type of the libobj
  and lowercase_name is the name of the libobj.
  """
  @spec to_btn(t, boolean()) :: Nostrum.Struct.Component.Button.t()
  def to_btn(value, disabled \\ false)

  @doc """
  Return the libobj as a button.
  Custom ID is expected to be in the format of `"(uuid)_(kind)_(lowercase_name)"`.
  Where the uuid is the given UUID as a 6 digit uppercase hex string,
  kind is a single letter that represents the type of the libobj,
  and lowercase_name is the name of the libobj.
  """
  @spec to_btn_with_uuid(t, boolean(), pos_integer()) :: Nostrum.Struct.Component.Button.t()
  def to_btn_with_uuid(value, disabled \\ false, uuid)

  @doc """
  Return the libobj as a semi-persistent button.
  Custom ID is expected to be in the format of `"(kind)r_(lowercase_name)"`.
  Where kind is a single letter that represents the type of the libobj,
  and lowercase_name is the name of the libobj.
  """
  @spec to_persistent_btn(t, boolean()) :: Nostrum.Struct.Component.Button.t()
  def to_persistent_btn(value, disabled \\ false)
end
