<p align="center">
  <img alt="Dojo Logo" src="./_assets/dojo.png" height="130" width="620" />
  <h2 align="center"><code>dojo-setup</code></h2>
  <p align="center">Quickly install all required dependencies to test your dojo project</p>
</p>


---

`dojo-setup` is a small action that automatically downloads and sets up a working dojo environment.

## Get started

You can use the following example to quickly test your project after each commit and pull request.

```yaml
name: Test contracts
on:
  # Replace this section with the branches in use in your own repository.
    push:
      branches:
        - "main"
    pull_request:
      branches:
        - "main"

permissions:
  contents: read

jobs:
  slot-deployment:
    runs-on: ubuntu-latest

    steps:
      - name: Setup repo
        uses: actions/checkout@v4

      - id: Setup Dojo
        uses: runelabsxyz/setup-dojo@main
        with:
          version: "v1.0.1"

      - name: Build contract
        # Add the following line if your contract is not at the root of the project.
        # working-directory: ./contracts
        run: sozo build 

      - name: Test contract
        # Add the following line if your contract is not at the root of the project.
        # working-directory: ./contracts
        run: sozo test
```

## Configuration

> [!INFO]
> We are still working in improving this action, so configuration is limited for now.

| Parameter | type   | description                                                                        |
| --------- | ------ | ---------------------------------------------------------------------------------- |
| `version` | string | The version of dojo to install. This would be the parameter you provide to dojoup. |

## Development

This actions uses the `dojoup` tool provided by the dojo engine organization to install a ready-to-use developpment environment for github actions.

## TODO

- [ ] Add support for version extraction from the asdf file
- [ ] Add cache support to improve the speed of builds