## README.md

No drift detected.

## scripts/README.md

- **The action return contract incorrectly includes two queries.** `scripts/README.md:15–20` lists `reachable` and `enemy_attack_preview` as expedition actions and says actions return dictionaries with `ok`/`error`. In fact, `reachable` returns a boolean (`scripts/game.gd:174–180`), while `enemy_attack_preview` returns an attack forecast (`scripts/game.gd:554–555`) containing `raw`, `damage`, `disrupted`, `redirected`, and `redirect_target`, without `ok`/`error` (`scripts/game.gd:574–589`). Separate these queries from the mutating action/result contract so callers do not treat either as an action-status dictionary.

## tools/README.md

- **Screenshot capture's filesystem side effects omit save writes.** The screenshot side-effect entry describes in-memory run/UI mutations, environment changes, and PNG output (`tools/README.md:39`), but capture also creates and repeatedly writes save files. It sets `/tmp/astral-docs-<ticks>` as `ASTRAL_SAVE_DIR` (`tools/capture_screenshots.gd:5–8`), calls `new_run` during each seed-search attempt (`tools/capture_screenshots.gd:19–22`), and commits `choose_node` for each combat capture (`tools/capture_screenshots.gd:43–45`). Both engine actions call `save()` (`scripts/game.gd:118–122`, `scripts/game.gd:192–200`), which invokes the store writer (`scripts/game.gd:932–936`); that writer creates the directory and writes/rotates primary, pending, and backup files (`scripts/save_store.gd:47–77`). Document these isolated on-disk saves and their retention: the capture exit path does not remove the temporary save directory (`tools/capture_screenshots.gd:60–64`).

## Casks/README.md

No drift detected.
