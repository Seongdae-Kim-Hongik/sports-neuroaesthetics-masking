# Sports image stimuli — controlled-access archive

The author supplied **24 image files forming 12 distinct scene pairs** on 2026-11-07. Each pair contains a face-visible (`standard`) and face-masked (`faceless`) version. All files are 1056 × 1056 pixels. The file count agrees with the manuscript's description of 12 base images prepared in two versions. It does not independently verify presentation logs or trial order.

## Files and names

`images/pairNN_scene_condition.ext` uses pair IDs 01–12, a descriptive scene label and the condition. Pair numbering is an archive index, **not presentation order**. Scene labels describe the visible activity and are not an experimental factor. Original bytes and formats are retained; JPEG `.jpeg` suffixes are normalized to `.jpg` without re-encoding. No image was edited, resampled or recompressed.

- `stimulus_manifest.csv`: all 24 files, original-to-new filename mapping, dimensions, byte counts, SHA-256 hashes, decoded-RGB hashes, historical project matches and provenance status.
- `stimulus_pairs.csv`: explicit Standard/Faceless pairs.
- `archived_asset_manifest.csv` and `archived_pairs.csv`: the earlier 12-asset/six-pair project inventory, retained for provenance.

Pairs 01–06 match all 12 archived JPEG asset hashes exactly. Pairs 07–12 are newly supplied PNG pairs whose source filename stems are 1, 2, 3, 4, 6 and 9. Their linkage to acquisition/project records has not been independently verified. They are not silently substituted into analysis inputs or block-condition coding.

## Access

The GitHub repository is private. Do not publish a public release or enable automatic GitHub–Zenodo archiving of the images. Zenodo deposit preparation specifies **restricted files**, no automatic embargo expiry, with access granted only after review by a corresponding author. No Zenodo record or DOI has yet been created.

Requests should describe the intended research use and be sent to Seongdae Kim, kimsd@hongik.ac.kr; co-corresponding author Seungbeom Kim, sbkim@hongik.ac.kr. Approval of file access does not confer copyright or unrestricted reuse rights. See `ACCESS_POLICY.md` and `RIGHTS.md`.
