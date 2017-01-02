defmodule Cafex.Mixfile do
  use Mix.Project

  def project do
    [app: :cafex,
     version: "0.0.3",
     elixir: "~> 1.2",
     description: description,
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     consolidate_protocols: Mix.env != :test,
     deps: deps,
     test_paths: test_paths(Mix.env),

     aliases: ["test.all": ["test.default", "test.integration"],
       "test.integration": &test_integration/1,
       "test.default": &test_default/1],
     preferred_cli_env: ["test.all": :test],

     name: "Cafex",
     source_url: "https://github.com/upyun/cafex",
     homepage_url: "http://cafex.github.com/",
     docs: [extras: ["README.md"]],
     package: package,
     dialyzer: [flags: ["-Werror_handling", "-Wrace_conditions", "-Wunderspecs"]]]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: [:logger, :erlzk, :consul],
     mod: {Cafex.Application, []}]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type `mix help deps` for more examples and options
  defp deps do
    [{:earmark, "~> 1.0.1", only: :dev},
     {:ex_doc,  "~> 0.13.0", only: :dev},
     {:consul, github: "zolazhou/consul-ex"},
     {:erlzk,   "~> 0.6.3"},
     {:snappy, "~> 1.1", only: [:dev, :test]}]
  end

  defp test_paths(:integration), do: ["integration_test"]
  defp test_paths(:all), do: ["test", "integration_test"]
  defp test_paths(_), do: ["test"]

  defp env_run(env, args) do
    args = if IO.ANSI.enabled?, do: ["--color"|args], else: ["--no-color"|args]

    IO.puts "==> Running tests for MIX_ENV=#{env} mix test"

    {_, res} = System.cmd "mix", ["test"|args],
                          into: IO.binstream(:stdio, :line),
                          env: [{"MIX_ENV", to_string(env)}]

    if res > 0 do
      System.at_exit(fn _ -> exit({:shutdown, 1}) end)
    end
  end

  defp test_integration(args), do: env_run(:integration, args)
  defp test_default(args), do: env_run(:test, args)

  defp package do
    [files: ~w(lib config/config.exs integration_test test LICENSE mix.exs mix.lock README.md),
     licenses: ["Apache 2.0"],
     maintainers: ["Belltoy Zhao"],
     links: %{"GitHub" => "https://github.com/upyun/cafex",
     name: "misha_cafex"}]
  end

  defp description do
    """
    Cafex is a pure Elixir implementation of Kafka client.
    """
  end
end
