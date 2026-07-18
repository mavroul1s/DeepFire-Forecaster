# SpaSE-UNet3D — MDPI Sensors Major Revision Plan

Manuscript: "SpaSE-UNet3D: Sensor-Driven Wildfire Detection and Progression Prediction from VIIRS Multispectral Imagery"
Authors: N. Mavros, D. Katsaros (University of Thessaly)
Decision: Major Revision, three reviewers
Repo: https://github.com/mavroul1s/DeepFire-Forecaster
Dataset: TS-SatFire, Zhao, Gerard & Ban, Sci Data 12:1817 (2025)
Reference code: https://github.com/zhaoyutim/TS-SatFire

---

## 0. Read this first: what changed since submission

Two findings from reading the TS-SatFire reference implementation change the
framing of the entire paper. Everything below depends on them.

### 0.1 The published baselines use a different metric than we do

From `run_spatial_temp_model.py` (lines 299–357) and
`run_spatial_temp_model_pred.py` (lines 295–362), the reference evaluation is:

```python
f1_ts = f1_score(label.flatten(), output_ti.flatten(), zero_division=1.0)
f1 += f1_ts                 # accumulate over frames
...
f1_all += f1/length         # mean over frames within one fire
...
print(f1_all/len(ids))      # unweighted mean over fires
```

Properties of that protocol:

| Property | Reference (TS-SatFire) | Ours (as submitted) |
|---|---|---|
| Aggregation | per-frame sklearn, macro over frames, then macro over fires | pixel-level micro over all test pixels |
| Empty ground truth | `zero_division=1.0` returns **1.0** | frame contributes nothing |
| Nodata handling | BA/FP: NaN → −1, prediction forced to 0, scores **1.0** | frames skipped |
| AF label rule | `nan_to_num(band7) > 0` | `band7 >= 7` |
| Decision threshold | fixed 0.5, no sweep | validation-swept |
| Test window stride | AF/BA: stride = TS; FP: stride = 1 | AF: stride 1; FP: stride 1 |
| Frames scored per window | all T | last frame only (AF) |

Consequence: **the +3.2 % (AF) and +4.9 % (FP) claims compare two different
metrics.** They are not model differences.

### 0.2 The metric identity confirms this independently

For binary micro-averaged metrics, `IoU = F1 / (2 − F1)` holds exactly.

- Our numbers obey it: AF 0.855 → 0.7467 (reported 0.746); FP 0.424 → 0.2690 (reported 0.269);
  training log `results_v6.json` 0.8248 → 0.70184 (reported 0.7018).
- Every TS-SatFire number violates it, always in the same direction:
  SwinUNETR-3D AF 0.823 implies 0.6993 but 0.727 is reported;
  U-Net-3D FP 0.375 implies 0.2308 but 0.338 is reported.

`f(x) = x/(2−x)` is convex, so a macro-average of per-frame IoU necessarily
exceeds the value implied by the macro-averaged F1, with a gap that grows with
across-frame variance. Observed gaps: ≈ 0.025 for AF/BA (low variance),
≈ 0.107 for FP (very high variance). This is exactly the predicted pattern.

Cross-check: the macro-average of our own 16 published per-fire FP F1 values is
0.3609 with macro IoU 0.2292 — a Jensen gap of only 0.009, because it is across
fires only. A gap of 0.107 requires frame-level averaging with many frames
pinned at exactly 0.0 or 1.0. Independent confirmation.

### 0.3 What the audit finding actually is (stronger than the submitted version)

The dataset paper states that AF training labels failing manual QC are removed,
and that missing values are replaced with zeros. In the released code:

- AF label: `af = np.nan_to_num(af[...])` → NaN becomes **0**
  (`satimg_dataset_processor.py`, line ~82)
- BA label: `label = np.nan_to_num(array_day[7], nan=-1)` → NaN becomes **−1**
  (line 79)

So one preprocessing convention produces two opposite failure modes:

1. **At training time**, an unlabelled fire becomes an all-negative example.
   This is the mechanism behind the ≈ 0.80 recall ceiling documented in Section 4.1.
2. **At test time (BA/FP)**, an unlabelled frame is masked and scored as a
   perfect 1.0, inflating published scores in proportion to how much of the test
   set is unlabelled.

For AF specifically the −1 path does **not** apply (NaN → 0, not −1), so
unlabelled AF test fires score 0.0 unless the model also predicts nothing.
Calf Canyon and Mosquito therefore most likely *depress* the published AF
baselines rather than inflating them.

This reframing is more precise, more checkable, and less accusatory than "the
benchmark has missing labels". It should become the paper's primary contribution.

### 0.4 Estimated magnitude of the correction

Macro-average of our own per-fire values, as a first approximation of the
reference protocol (not the true frame-level value, which the protocol run will
produce):

| Task | Our micro (submitted) | Our per-fire macro | Published baseline |
|---|---|---|---|
| AF (15 fires) | 0.855 | 0.840 | 0.823 (SwinUNETR-3D, TS=2) |
| FP (16 fires) | 0.424 | 0.361 | 0.375 (U-Net-3D, TS=6) |

**The FP result falls below the baseline under fire-level macro-averaging.**
The true reference-protocol value may be higher because empty frames score 1.0,
but this must be measured, not assumed.

---

## 1. Decision point

Everything in Sections 2–5 is unblocked and should be written now. The
following items have two mutually exclusive versions and must not be drafted
until the protocol evaluation returns numbers:

- Abstract, sentences 3–5 (the quantitative claims)
- Section 6.2, paragraphs 1 and 5 (AF comparison)
- Section 6.3, paragraphs 1 and 3 (FP comparison)
- Section 7, "Data quality is a first-class contribution" (delta figures)
- Section 8, Conclusion, sentence 2

### Branch A — we lead under the matched protocol

Framing: "Under the benchmark's own evaluation code, SpaSE-UNet3D improves on
the best published baseline by X, using one third of the temporal context."
Requires: reference-protocol F1 above 0.823 (AF) / 0.375 (FP) on the full
official test sets. Keep the SOTA claim but state the protocol explicitly and
report both aggregations in every table.

### Branch B — we do not lead on one or both tasks

Framing shifts to:
1. Primary contribution: the evaluation-protocol and label-encoding finding,
   quantified (Section 0.3), which affects every number published on this benchmark.
2. Secondary contribution: an architecture that is competitive at TS ∈ {1,2}
   versus baselines at TS = 6, with the spatial-only convolution ablation
   supporting the inductive-bias claim.
3. Remove "state of the art" from abstract, Section 6, and Conclusion.

Branch B is what R3 has already asked for ("moderate the claim… unless the
comparison is performed under the same evaluation protocol") and what R2's first
question implies. It is publishable. Do not treat it as failure.

**Do not select the aggregation that produces the more favourable number.**
Report both, state which is the benchmark's, and let the comparison stand.

---

## 2. Factual corrections (unblocked — do these now)

All verified against source files or the reference repository.

| # | Location | Current text | Correction | Evidence |
|---|---|---|---|---|
| C1 | Abstract, l. 9 | "18 training fires and 2 test fires" | Must match Table 1. See C2. | R2 |
| C2 | Table 1, Section 4.1 | Train 138 / 117 usable / 21 excluded | Training code excludes **18** train IDs (+1 val); `results_v6.json` records `train_fires_excluded: 18`, `train_fires_clean: 120`. Re-derive and state one definition: explicitly excluded (18) vs. effectively unavailable including missing `VIIRS_Day` directories (possibly 21). | `af_2day_input__train.ipynb` `NO_LABEL_IDS`; `results_v6.json` |
| C3 | Section 4.1 | "The 2 excluded test fires are Calf Canyon and Mosquito. The two test fires, Calf Canyon and Mosquito, are 2022 events…" | Duplicated sentence; merge into one. | manuscript |
| C4 | Section 6.3 ¶3, Fig. 6 caption | "six AZ/NM fires excluded" | **Eight**; `FP_TEST_EXCLUDE` has 8 entries (1 FL, 1 MT, 4 NM, 2 AZ). Table 3 is correct; the prose is not. Also correct the state list. | `fire_pred_2day_input.ipynb` CFG |
| C5 | Section 5.1, p. 6 ll. 216–221; Fig. 1 caption | "The temporal dimension T is… never mixed" | False as stated. Convolutions do not mix time, but SEBlock3D pools over (T,H,W) and the FP head mean-pools over T. Rewrite: "no temporal mixing in the convolutional path; temporal aggregation occurs only in SE pooling and, for FP, the final temporal mean-pool." | R2; `SEBlock3D`, `SEUNet3DPred.forward` |
| C6 | Section 5.1, Fig. 1 caption | "All convolutions use kernel (1,3,3)" | False: 1×1×1 skip projections, ConvTranspose3D (1,2,2), ASPP dilated branches, the 27→64 stem, and a 2D output head. Rewrite as "all spatial feature-extraction convolutions in the encoder and decoder residual blocks". | R2; model code |
| C7 | Sections 6.1 and 6.2 | "[0.20, 0.22]" and "validation-optimum threshold of 0.20" | Training log records `optimal_threshold: 0.25`. Neither stated value matches. State the actual sweep and the actual selected value once. | `results_v6.json` |
| C8 | Section 5.3 "Test-time augmentation"; Fig. 3; Section 6.1 FP; Section 7 Limitations | "8× test-time augmentation at inference" | **The FP notebook contains no TTA.** Only train-time flips. Either remove all TTA claims, or re-run with TTA and report it. Recommended: remove, and state that TTA was evaluated and rejected (consistent with the sparse-prediction finding). | `fire_pred_2day_input.ipynb` |
| C9 | Section 6.3 ¶ after Table 6 | "considerably smaller than transformer variants" | 32.88M (AF) vs U-Net-3D 31.7M, SwinUNETR-3D 33.2M, UNETR-3D 34.8M. Not smaller. Only Att-U-Net-3D (94.5M) is larger. Rewrite or delete. FP at 24.28M *is* smaller and can be stated. | TS-SatFire Table 3 |
| C10 | Section 6.2 ¶2 | "validation F1 crossed the SwinUNETR-3D paper baseline (0.823)" | Compares our **validation** F1 against their **test** F1. Invalid. Remove the comparison or restate as a training-progress observation with no baseline reference. | `results_v6.json` (`best_f1` is validation) |
| C11 | Table 5 caption; Section 6.3 | F1/IoU pairs appear inconsistent (R3) | Explain: our values satisfy IoU = F1/(2−F1); the baselines' do not, because their aggregation differs. Add the identity as a one-line footnote. | Section 0.2 |
| C12 | Section 3.2 | FP validation "extends the AF/BA list from 13 to 15" | Cross-check against `PRED_VAL_IDS` (15 IDs listed, one absent from the Kaggle release → 14 replicable). Confirm the arithmetic and state it once. | `fire_pred_2day_input.ipynb` CFG |
| C13 | Abstract | Does not state that BA is audit-only | Add explicit sentence (R3). | R3 |
| C14 | Abstract, l. 8 | Grammar (R1) | "…to recover an unbiased recall" → "…to obtain unbiased recall". Proofread the whole abstract. | R1 |
| C15 | Section 4.2 | "49 of 138 training fires" with breakdown 14 + 18 + 17 | 14+18+17 = 49, consistent. Verify the same arithmetic for AF (14+4+3 = 21) against C2. | manuscript |

---

## 3. Reviewer response matrix

### Reviewer 1

| Item | Action | Status |
|---|---|---|
| R1.1 Grammar, line 8 | C14; full language pass | Unblocked |
| R1.2 Explain Equation 1 in more detail | Expand Section 3.1: what band 8 stores (Julian-day codes / perimeter IDs in [2,119 – 908,660]), why presence-of-finite rather than a value threshold, what NaN means, and the −1 sentinel introduced by the reference loader. Add a worked example. Cross-reference Section 0.3. | Unblocked |
| R1.3 Metrics, epoch-based improvement, ablations | Add per-epoch validation F1/IoU curves for AF and FP (E5); add the ablation table (E3). | Partly blocked |

### Reviewer 2

| Item | Action | Status |
|---|---|---|
| R2.1 Were baselines recomputed on the same fires? | **No.** State plainly in the response letter. Resolve via E1 (protocol evaluation) rather than retraining their models. Report both aggregations for our model on both test populations. | Blocked on E1 |
| R2.2 Establish a matched, transparent comparison protocol | E1 + new Section 6.1 subsection "Evaluation protocol", documenting all seven differences in the Section 0.1 table. | Blocked on E1 |
| R2.3 How many configurations were tested; nested/repeated validation? | Answer honestly: choices were made sequentially on a single validation split (8 usable FP fires), with no nested CV. Report the number of configurations actually tried per decision from the v1–v6 notebook history. Add this as an explicit limitation. | Unblocked |
| R2.4 Ablation claim about full (3,3,3) convolutions has no table | E3 with 3 seeds. | Blocked on E3 |
| R2.5 Abstract 18 vs Section 4.1/Table 1 21 | C2 | Unblocked |
| R2.6 Table 3 / Fig. 6 say eight, text says six | C4 | Unblocked |
| R2.7 Temporal dimension "never mixed" | C5 | Unblocked |
| R2.8 Threshold selection inconsistent | C7 | Unblocked |
| R2.9 "All convolutions use (1,3,3)" | C6 | Unblocked |

### Reviewer 3

| Item | Action | Status |
|---|---|---|
| R3.1 Abstract: clarify BA is audit-only; moderate SOTA claim | C13; SOTA language depends on branch | Partly blocked |
| R3.2 Introduction: research gap not obvious | Rewrite ¶3: prior TS-SatFire work compares architectures on unaudited labels with an evaluation protocol that scores unlabelled frames as correct; no prior work quantifies either effect. | Unblocked |
| R3.3 Introduction: state novelty explicitly | "Two contributions: (i) a label-quality and evaluation-protocol audit of TS-SatFire; (ii) SpaSE-UNet3D." Name which is primary (branch-dependent). | Partly blocked |
| R3.4 Introduction: summarise objectives at the end | Add a four-item objectives paragraph. | Unblocked |
| R3.5 Moderate spatial-only superiority claims | Soften throughout; defer to E3. | Unblocked |
| R3.6 Add two references | DOI 10.17707/AgricultForest.69.3.06 and DOI 10.15244/pjoes/152835. Cite in the Introduction background sentence (ll. 22–26) as general wildfire/environmental remote-sensing context. Verify both exist and are described accurately before citing. | Unblocked |
| R3.7 Related Work is descriptive, not critical | Rewrite with explicit comparison; add a paragraph on how SpaSE-UNet3D differs from U-Net-3D / Att-U-Net-3D / UNETR-3D / SwinUNETR-3D (kernel factorisation, SE placement, bottleneck, head). | Unblocked |
| R3.8 More discussion of data quality in RS benchmarks | Expand using Pelletier et al. [20], Northcutt et al. [21], Moreno-Ruiz et al. [22]; connect to Section 0.3. | Unblocked |
| R3.9 Single table of original vs final usable counts | New Table 1 replacing Tables 1–3: rows = task × split, columns = total / usable / excluded / reason breakdown. | Unblocked |
| R3.10 FirePred variables described poorly | The dataset paper's Table 1 names all 27 channels (I1–I5, M11, I4/I5 Night, NDVI, EVI, precipitation, wind speed/direction, min/max temperature, ERC, specific humidity, slope, aspect, elevation, PDSI, land cover, and four forecast variables). Reproduce the 18 we use, with the index mapping, and state that band 3 (I3) is dropped as all-zero in our probe fire — and verify that claim across more fires. | Unblocked |
| R3.11 Does the 256×256 crop exclude part of the fire? | E4: measure, per test fire, the fraction of labelled positive pixels falling outside the centre crop. Report as a table. This also substantiates the FP exclusions. | Unblocked, cheap |
| R3.12 Justify exclusion criteria; sensitivity analysis | E4: recompute aggregates at burn-fraction thresholds {0, 1e-5, 1e-4, 1e-3, 1e-2} and at the < 50 %-usable-days criterion varied over {25, 50, 75} %. Report a sensitivity curve. | Unblocked, cheap |
| R3.13 Report on the complete official test set | E1 produces this directly. Argue politely that unlabelled fires measure annotation, not model quality — but report the number. | Blocked on E1 |
| R3.14 Systematic ablation | E3 | Blocked on E3 |
| R3.15 Cumulative BA mask may be unavailable to baselines | E3 arm "no cumBA". Note that the reference FP pipeline also aggregates I4/I5 by cumulative maximum, so some burned-area history is available to the baselines too — state this accurately. | Blocked on E3 |
| R3.16 Justify loss weights and pos_weight | Report the search actually performed (see R2.3) and the sensitivity where known. Do not invent a search that did not happen. | Unblocked |
| R3.17 Retrain baselines under the same protocol | Superseded by E1: we adopt *their* metric rather than reimplementing *their* models. Explain this choice in the response letter — it removes our reimplementation as a confound. Optionally E2 for calibration. | Blocked on E1 |
| R3.18 Multiple random seeds, mean ± std | E2. Precedent: TS-SatFire's own Table 4 reports seeds 42/43/44 with σ ≤ 0.013. | Blocked on E2 |
| R3.19 Explain FP per-fire variability | Expand Section 6.3 using E4 crop-coverage numbers; separate "small true progression signal" from "signal outside the crop". | Partly blocked |
| R3.20 Clarify Table 5 F1/IoU | C11 | Unblocked |
| R3.21 Moderate conclusions; single benchmark | Rewrite Section 7. | Unblocked |
| R3.22 Discuss limitations of the reduced evaluation set | Expand Limitations; include the full-test-set numbers from E1. | Blocked on E1 |
| R3.23 Applicability to other sensors/datasets | New Discussion paragraph: what transfers (spatial-only bias for short stacks, the audit methodology) and what does not (VIIRS-specific normalisation, band selection). | Unblocked |
| R3.24 Conclusion: no SOTA claim until matched | Branch-dependent | Blocked |
| R3.25 Future work: independent validation, ablations, more datasets | Rewrite final paragraph. | Unblocked |

### Reviewer scorecards

Two of three reviewers marked "Are all figures and tables clear and well-presented?" as needing improvement (one "must be improved"). Actions:

- Merge Tables 1–3 into one audit table (R3.9)
- Add the evaluation-protocol table (Section 0.1)
- Figures 5 and 7 are 15- and 16-panel grids with per-fire F1 in a separate caption table; move the F1 values into the panel titles and reduce to 6–8 representative panels, with the full grids as supplementary
- Add per-epoch training curves (R1.3)
- Ensure every table states the aggregation used

---

## 4. Experiments

All runs on Kaggle. Note: the session used for debugging had **2× T4**, not 4.
Budget accordingly.

### E1 — Protocol evaluation (inference only) — DO FIRST

Notebook: `protocol_eval_kaggle.ipynb` (already written, edits 1–8 applied).

Blocking issue: checkpoints and `fp_stats.npz` must be attached as Kaggle inputs
(Add Input → Notebook Output). Last run failed with `total: 0` checkpoint files
found.

Outputs: for AF and FP, reference-macro and micro F1/IoU on both the full
official test set and the audited subset, plus `n_free_score / n_frames` (the
count of frames scoring 1.0 through the empty branch).

AF is run in three configurations to decompose the protocol gap:

| tag | stride | label rule | frames scored |
|---|---|---|---|
| `af_reference` | 2 | `nan_to_num(b7) > 0` | all T |
| `af_ourlabel` | 2 | `b7 >= 7`, skip unlabelled | all T |
| `af_lastframe` | 1 | `b7 >= 7`, skip unlabelled | last only |

Acceptance criterion: `af_lastframe` micro F1 on the 15 audited fires must
reproduce 0.855 ± 0.005, and FP micro F1 at threshold 0.55 on the 16 audited
fires must reproduce 0.424 ± 0.010. **If not, the loader is wrong, not the
model** — in particular `build_fp_aux` (cumulative-BA channel, FirePred crop
alignment) is reconstructed from the training notebook and unverified.

Runtime: ~30 min on 2× T4.

### E2 — Seed replicates

Three seeds (42, 43, 44) for each headline arm; report mean ± std.

| Arm | Epochs | Approx. hours/run |
|---|---|---|
| AF TS=2, audited training | 80 | 6.5 |
| AF TS=2, unaudited training | 80 | 6.5 |
| FP TS=2, audited training | 60 | 3.5 |
| FP TS=2, unaudited training | 60 | 3.5 |

With 2 GPUs, two runs proceed in parallel per session. AF needs 3 sessions,
FP needs 2. All runs must checkpoint and support resume.

The train-audited / train-unaudited × test-full / test-audited 2×2 comes from
these same trainings; the test axis is inference-only.

Single seed is acceptable for: the 2×2 diagonal cells, AF TS=1, and E3 arms if
budget is tight (but R3 explicitly asked for repeats on the headline numbers).

### E3 — Ablation (leave-one-out from the full model, 3 seeds, reduced epochs)

Hold the epoch budget fixed across all arms (AF 40, FP 40). Report mean ± std
of validation F1 and test F1 under both aggregations.

AF arms: full model; (3,3,3) convolutions instead of (1,3,3); no SE; no deep
supervision; no Dropout3D; ReLU→GELU.

FP arms: full model; no ASPP (plain bottleneck); no SE; no cumulative-BA
channel; no BCE term; with 8× TTA; per-frame SE pooling over (H,W) only.

The last FP arm doubles as the experiment that turns correction C5 into a
contribution: it tests whether the SE block's temporal pooling matters.

Budget: 13 arms × 3 seeds = 39 runs. At ~3 h each on 2 GPUs, ~59 sessions is
infeasible. **Reduce scope:** run 3 seeds only for the four arms that support
explicit claims in the text ((3,3,3) vs (1,3,3), no SE, no ASPP, no cumBA) and
1 seed for the rest. That is 4×3 + 9 = 21 runs ≈ 11 sessions. Confirm this is
acceptable before starting.

### E4 — Audit sensitivity and crop coverage (inference only, cheap)

1. Per test fire, fraction of labelled positive pixels outside the 256×256
   centre crop (answers R3.11 and substantiates the FP exclusions).
2. Aggregate F1 recomputed at burn-fraction exclusion thresholds
   {0, 1e-5, 1e-4, 1e-3, 1e-2} (answers R3.12).
3. Train-split usable-days criterion varied over {25, 50, 75} % — report how
   many fires change status. Retraining is not required to report the counts;
   only report performance impact if E2 budget allows.
4. Verify the "FirePred band 3 is all zeros" claim across all training fires,
   not one probe fire (R3.10).

Runtime: under 1 h. No GPU strictly required for items 1, 3, 4.

### E5 — Training curves

Extract per-epoch validation F1/IoU from existing training logs for AF and FP
and plot. Answers R1.3. No new compute if the logs were saved; otherwise
falls out of E2.

---

## 5. Section-by-section writing plan

| Section | Work | Blocked? |
|---|---|---|
| Abstract | C13, C14; state BA is audit-only; quantitative claims deferred | Partly |
| 1. Introduction | R3.2–R3.6; add objectives paragraph; add two references | No |
| 2. Related Work | R3.7, R3.8; add architecture-difference paragraph | No |
| 3. Dataset | R3.9 (merged table), R3.10 (FirePred documentation), R3.11 (crop) | No |
| 3.1 Labels | R1.2 (expand Eq. 1); document the −1 sentinel | No |
| 4. Audit | Restructure around Section 0.3; add E4 sensitivity; add the evaluation-protocol finding as a new subsection 4.4 | Partly |
| 5. Method | C5, C6, C8; justify hyperparameters honestly (R2.3, R3.16) | No |
| 6.1 Experiments | New "Evaluation protocol" subsection with the Section 0.1 table; C7 | Partly |
| 6.2 AF results | C10; both aggregations; both test populations | Blocked on E1 |
| 6.3 FP results | C4, C9, C11; R3.19 | Blocked on E1 |
| 6.4 Ablation (new) | E3 | Blocked on E3 |
| 7. Discussion | R3.21–R3.23; rewrite Limitations | Partly |
| 8. Conclusion | R3.24, R3.25 | Blocked |
| Response letter | Point-by-point; lead with the protocol finding and an explicit acknowledgement that the original comparison was not matched | Blocked on E1 |

---

## 6. Open questions requiring author input

1. **E3 scope.** Is 21 ablation runs (~11 sessions) acceptable, or should it be
   cut further?
2. **Branch B acceptance.** Confirm willingness to remove the SOTA claim if E1
   does not support it.
3. **TTA (C8).** Confirm the winning FP run used no TTA, so the text can be
   corrected rather than the experiment re-run.
4. **C2 definition.** Which is authoritative: 18 explicitly excluded, or 21
   including fires with no `VIIRS_Day` directory? Needs a re-run of the audit
   script to state both cleanly.
5. **R3.6 references.** Confirm the two suggested DOIs will be cited.
6. **Checkpoint availability.** Are the AF TS=2 and FP v6 training outputs still
   available as Kaggle notebook outputs? E1 and much of the response depend on
   them. If lost, AF retraining is one 6.5 h session.

---

## 7. Sequencing

1. Attach checkpoints; run E1. (30 min)
2. Read E1; select Branch A or B.
3. Run E4 in the same session or the next. (1 h)
4. Write all unblocked corrections and sections (Section 2, Section 5 rows
   marked "No").
5. Run E2. (5 sessions)
6. Run E3 at agreed scope. (~11 sessions)
7. Assemble results sections, ablation table, response letter.
8. Final consistency pass: every number in the manuscript re-derived from a
   logged artifact, not from memory. Every table states its aggregation.

---

## 8. Standing principles for this revision

- Report both aggregations everywhere. Never present a comparison between two
  different metrics as a model difference.
- Every claim in the text must be traceable to a saved artifact (log, JSON,
  checkpoint). The TTA discrepancy (C8) and the threshold discrepancy (C7) both
  arose from text drifting away from code.
- Prefer measuring the reviewers' objections over arguing with them. Where we
  disagree (R3.13), report the requested number *and* the argument.
- Do not describe experiments that were not run.
