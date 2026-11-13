This is an Elixir app powered by Ash & Phoenix LiveView.

- use Ash concepts, not Ecto directly; new resources, validations, changes and
  calculations are module-based, created with the Ash generators (`mix help` lists
  them; pass `--yes`) and then modified
- Mix isn't available in prod, so don't call `Mix.env()` in application code
