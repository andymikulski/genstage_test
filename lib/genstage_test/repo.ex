defmodule GenstageTest.Repo do
  use Ecto.Repo,
    otp_app: :genstage_test,
    adapter: Ecto.Adapters.Postgres
end
