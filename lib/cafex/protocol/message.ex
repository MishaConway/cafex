defmodule Cafex.Protocol.Message do
  defstruct topic: nil,
            partition: nil,
            value: nil,
            key: nil,
            offset: 0,
            magic_byte: 0,
            attributes: 0,
            metadata: nil

  @type t :: %Cafex.Protocol.Message{ topic: binary,
                                      partition: integer,
                                      value: binary,
                                      key: binary,
                                      offset: integer,
                                      magic_byte: integer,
                                      attributes: integer,
                                      metadata: term }

  def from_tuple({topic, partition, value}), do: from_tuple({topic, partition, value, nil})
  def from_tuple({topic, partition, value, key}) do
    %Cafex.Protocol.Message{ topic: topic,
                             partition: partition,
                             value: value,
                             key: key }
  end
end
