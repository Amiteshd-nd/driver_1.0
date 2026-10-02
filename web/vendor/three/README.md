# three (vendored)

Three.js **0.186.1**, copied unmodified from the npm tarball (`npm pack three@0.186.1`), MIT licence (see LICENSE).

- `three.module.js` + `three.core.js`: the ESM build. Pages import it through an import map
  (`"three": "../vendor/three/three.module.js"`), so core and any future addons stay on one
  pinned release (ui-ux-pro-max threejs rule 1 and 5).
- The build is unminified (2.1 MB). Before a public launch, minify or bundle it; the import map
  path is the only thing that changes.
- To upgrade: `npm pack three@<version>`, copy the same two files, update this line.
