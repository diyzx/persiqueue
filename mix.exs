defmodule Persiqueue.MixProject do
  use Mix.Project

  def project do
    [
      app: :persiqueue,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      applications: [:libcluster],
      mod: {Persiqueue, []}
    ]
  end

  defp deps do
    [
      {:libcluster, "~> 2.5"},
      {:amnesia, git: "https://github.com/meh/amnesia.git"}
    ]
  end
end
