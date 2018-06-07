use Mix.Config

{:ok, host} = :inet.gethostname

config :libcluster,
  topologies: [
    epmd: [
      strategy: Cluster.Strategy.Epmd,
      config: [
        hosts: [:"node1@#{host}", :"node2@#{host}", :"node3@#{host}"]
      ]
    ]
  ]
