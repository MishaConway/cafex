defmodule Cafex.Protocol do
  @moduledoc """
  This module provide encode/decode functions for common structures in Kafka protocol.

  And also provide conveniences for implementing API request and the `Cafex.Protocol.Request`.

  ## APIs

    * `Cafex.Protocol.Metadata`
      - `Cafex.Protocol.Metadata.Request`
      - `Cafex.Protocol.Metadata.Response`
    * `Cafex.Protocol.Produce`
      - `Cafex.Protocol.Produce.Request`
      - `Cafex.Protocol.Produce.Response`
    * `Cafex.Protocol.Fetch`
      - `Cafex.Protocol.Fetch.Request`
      - `Cafex.Protocol.Fetch.Response`
    * `Cafex.Protocol.Offset`
      - `Cafex.Protocol.Offset.Request`
      - `Cafex.Protocol.Offset.Response`
    * `Cafex.Protocol.ConsumerMetadata`
      - `Cafex.Protocol.ConsumerMetadata.Request`
      - `Cafex.Protocol.ConsumerMetadata.Response`
    * `Cafex.Protocol.OffsetCommit`
      - `Cafex.Protocol.OffsetCommit.Request`
      - `Cafex.Protocol.OffsetCommit.Response`
    * `Cafex.Protocol.OffsetFetch`
      - `Cafex.Protocol.OffsetFetch.Request`
      - `Cafex.Protocol.OffsetFetch.Response`
  """

  @type api_version :: 0 | 1 | 2
  @type api_key :: 0..10

  alias Cafex.Protocol.Request
  alias Cafex.Protocol.Message

  defmacro __using__(_opts) do
    impls = impl_request(__CALLER__.module)
    quote do
      @behaviour Cafex.Protocol.RequestBehaviour
      @before_compile unquote(__MODULE__)

      def has_response?(_), do: true

      defimpl Request do
        unquote(impls)
      end

      defoverridable [has_response?: 1]
    end
  end

  defmacro __before_compile__(env) do
    api_key = env.module |> Module.get_attribute(:api_key)
    api_version = env.module |> Module.get_attribute(:api_version)

    quote do
      def api_key(_), do: unquote(api_key)

      def api_version(_) do
        case unquote(api_version) do
          nil -> 0
          version -> version
        end
      end

      defoverridable [api_version: 1, api_key: 1]
    end
  end

  defp impl_request(module) do
    [:api_key, :api_version, :has_response?, :encode]
    |> Enum.map(fn func ->
      quote do
        def unquote(func)(req), do: unquote(module).unquote(func)(req)
      end
    end)
  end

  def has_response?(request), do: Request.has_response?(request)

  def encode_request(client_id, correlation_id, request) do
    api_key = Request.api_key(request)
    api_version = Request.api_version(request)
    payload = Request.encode(request)
    << api_key :: 16, api_version :: 16, correlation_id :: 32,
       byte_size(client_id) :: 16, client_id :: binary,
       payload :: binary >>
  end

  def decode_response(decoder, << correlation_id :: 32, rest :: binary >>) do
    {correlation_id, decoder.decode(rest)}
  end

  @doc """
  Encode bytes

  ## Examples

      iex> encode_bytes(nil)
      <<255, 255, 255, 255>>

      iex> encode_bytes("")
      <<255, 255, 255, 255>>

      iex> encode_bytes("hey")
      <<0, 0, 0, 3, 104, 101, 121>>
  """
  @spec encode_bytes(nil | binary) :: binary
  def encode_bytes(nil), do: << -1 :: 32-signed >>
  def encode_bytes(data) when is_binary(data) do
    case byte_size(data) do
      0 -> << -1 :: 32-signed >>
      size -> << size :: 32-signed, data :: binary >>
    end
  end

  def decode_bytes(<< -1 :: 32-signed, rest :: binary >>) do
    {nil, rest}
  end
  def decode_bytes(<< size :: 32-signed, bytes :: size(size)-binary, rest :: binary >>) do
    {bytes, rest}
  end

  @doc """
  Encode string

  ## Examples

      iex> encode_string(nil)
      <<255, 255>>

      iex> encode_string("")
      <<255, 255>>

      iex> encode_string("hey")
      <<0, 3, 104, 101, 121>>
  """
  @spec encode_string(nil | binary) :: binary
  def encode_string(nil), do: << -1 :: 16-signed >>
  def encode_string(data) when is_binary(data) do
    case byte_size(data) do
      0 -> << -1 :: 16-signed >>
      size -> << size :: 16-signed, data :: binary >>
    end
  end

  @doc """
  Encode kafka array

  ## Examples

      iex> encode_array([], nil)
      <<0, 0, 0, 0>>

      iex> encode_array([1, 2, 3], fn x -> <<x :: 32-signed>> end)
      [<<0, 0, 0, 3>>, [<<0, 0, 0, 1>>, <<0, 0, 0, 2>>, <<0, 0, 0, 3>>]]
  """
  def encode_array([], _), do: << 0 :: 32-signed >>
  def encode_array(array, item_encoder) when is_list(array) do
    [<< length(array) :: 32-signed >>, Enum.map(array, item_encoder)]
  end

  @doc """
  Decode kafka array

  ## Examples

      iex> decode_array(<<0, 0, 0, 2, 0, 0, 0, 1, 0, 0, 0, 2>>, fn <<x :: 32, rest :: binary>> -> {x, rest} end)
      {[1, 2], <<>>}
  """
  def decode_array(<< num_items :: 32-signed, rest :: binary >>, item_decoder) do
    decode_array_items(num_items, rest, item_decoder, [])
  end

  defp decode_array_items(0, rest, _, acc), do: {Enum.reverse(acc), rest}
  defp decode_array_items(num_items, data, item_decoder, acc) do
    {item, rest} = item_decoder.(data)
    decode_array_items(num_items - 1, rest, item_decoder, [item|acc])
  end

  @doc """
  Encode single kafka message

  ## Examples

      iex> encode_message(%Cafex.Protocol.Message{value: "hey"})
      <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 17, 254, 46, 107, 157, 0, 0, 255, 255, 255, 255, 0, 0, 0, 3, 104, 101, 121>>

      iex> encode_message(%Cafex.Protocol.Message{value: "hey", key: ""})
      <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 17, 254, 46, 107, 157, 0, 0, 255, 255, 255, 255, 0, 0, 0, 3, 104, 101, 121>>

      iex> encode_message(%Cafex.Protocol.Message{value: "hey", key: "key"})
      <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 20, 156, 151, 255, 143, 0, 0, 0, 0, 0, 3, 107, 101, 121, 0, 0, 0, 3, 104, 101, 121>>
  """
  @spec encode_message(Message.t) :: binary
  def encode_message(%Message{magic_byte: magic_byte,
                              attributes: attributes,
                              offset: offset,
                              key: key,
                              value: value}) do
    sub = << magic_byte :: 8, attributes :: 8,
             encode_bytes(key) :: binary, encode_bytes(value) :: binary >>
    crc = :erlang.crc32(sub)
    msg = << crc :: 32, sub :: binary >>
    << offset :: 64-signed, byte_size(msg) :: 32-signed, msg :: binary >>
  end

  @doc """
  Decode message

  ## Examples

      iex> decode_message(<<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 17, 254, 46, 107, 157, 0, 0, 255, 255, 255, 255, 0, 0, 0, 3, 104, 101, 121>>)
      {%Cafex.Protocol.Message{value: "hey"}, <<>>}

      iex> decode_message(<<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 17, 254, 46, 107, 157, 0, 0, 255, 255, 255, 255, 0, 0, 0, 3, 104, 101, 121>>)
      {%Cafex.Protocol.Message{value: "hey", key: nil}, <<>>}

      iex> decode_message(<<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 20, 156, 151, 255, 143, 0, 0, 0, 0, 0, 3, 107, 101, 121, 0, 0, 0, 3, 104, 101, 121>>)
      {%Cafex.Protocol.Message{value: "hey", key: "key"}, <<>>}
  """
  def decode_message(<< offset :: 64-signed,
                        msg_size :: 32-signed, msg :: size(msg_size)-binary,
                        rest :: binary >>) do
    << _crc :: 32, magic :: 8, attributes :: 8, data :: binary >> = msg
    {key, data} = decode_bytes(data)
    {value,  _} = decode_bytes(data)
    {%Message{key: key,
              value: value,
              magic_byte: magic,
              attributes: attributes,
              offset: offset}, rest}
  end
  def decode_message(rest) do
    {nil, rest}
  end

  @doc """
  Encode MessageSet
  """
  @spec encode_message_set([Message.t]) :: binary
  def encode_message_set(messages) do
    Enum.map(messages, &encode_message/1) |> IO.iodata_to_binary
  end

  @doc """
  Decode MessageSet
  """
  @spec decode_message_set(binary) :: [Message.t]
  def decode_message_set(data) do
    decode_message_set_item(data, [])
  end

  defp decode_message_set_item(<<>>, acc), do: Enum.reverse(acc)
  defp decode_message_set_item(data, acc) do
    {msg, rest} = decode_message(data)
    case msg do
      nil ->
        decode_message_set_item(<<>>, acc)
      msg ->
        decode_message_set_item(rest, [msg|acc])
    end
  end
end
