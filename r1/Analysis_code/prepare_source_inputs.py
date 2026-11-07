"""Prepare revision survey/eye inputs from retained XLSX exports.

This reconstructs the input transformation, not the acquisition-quality decision.
The fixed eye sample is supplied explicitly in a membership manifest.
No names, contact fields, or identity crosswalk are written to outputs.
"""
import argparse
import hashlib
import json
from pathlib import Path

import pandas as pd


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--survey-xlsx', type=Path, required=True)
    ap.add_argument('--eye-xlsx', type=Path, required=True)
    ap.add_argument('--membership', type=Path, required=True)
    ap.add_argument('--output-root', type=Path, required=True)
    args = ap.parse_args()
    spec = json.loads(args.membership.read_text())
    for label, file in [('survey', args.survey_xlsx), ('eye', args.eye_xlsx)]:
        if digest(file) != spec['source_sha256'][label]:
            raise ValueError(f'{label}: source hash does not match the audited export')
    output = args.output_root / 'inputs_private'
    output.mkdir(parents=True, exist_ok=True)
    if any((output / x).exists() for x in ['survey_long.csv', 'eye_long.csv', 'cues.csv']):
        raise FileExistsError('Use a fresh output root; existing analysis inputs are not overwritten')
    survey = pd.read_excel(args.survey_xlsx, sheet_name=0)
    names = survey['e_name'].astype(str).str.strip().str.lower()
    if names.isna().any() or names.duplicated().any() or names.eq('nan').any():
        raise ValueError('Missing or duplicate private participant key')
    mapping = {v: f'P{i+1:03d}' for i, v in enumerate(sorted(names))}
    survey['ID'] = names.map(mapping)
    question_columns = [f'Q_{i}' for i in range(63, 123)]
    answered = survey[question_columns].notna().sum(axis=1)
    if not answered.isin([0, 60]).all():
        raise ValueError('Partial questionnaire record requires an explicit handling decision')
    selected = survey.loc[answered.eq(60)].copy()
    if set(selected.ID) != set(spec['survey_ids']):
        raise ValueError('Survey sample differs from the audited membership')
    if set(spec['survey_condition_by_block']) != set(map(str, range(1, 13))):
        raise ValueError('Missing questionnaire condition mapping')
    metrics = ['Emotion', 'Liveliness', 'Excitement', 'Immersion', 'Attractiveness']
    rows = []
    for _, rec in selected.iterrows():
        for trial in range(1, 13):
            for offset, metric in enumerate(metrics):
                value = float(rec[f'Q_{63+(trial-1)*5+offset}'])
                if value not in [1, 2, 3, 4, 5]:
                    raise ValueError('Rating outside the original five-point scale')
                rows.append(dict(ID=rec.ID, Group=str(rec.Group_behavior).upper(),
                                 Condition=spec['survey_condition_by_block'][str(trial)],
                                 Metric=metric, Trial=trial, Value=value))
    survey_long = pd.DataFrame(rows)
    eye = pd.read_excel(args.eye_xlsx, sheet_name=0)
    eye['ID'] = eye.Participant.astype(str).str.strip().str.lower().map(mapping)
    if eye.ID.isna().any():
        raise ValueError('An eye participant cannot be mapped to the survey key')
    if not set(spec['eye_ids']).issubset(set(eye.ID)):
        raise ValueError('Retained eye participant missing from source export')
    if not set(eye.J_Group).issubset({'masking', 'control'}):
        raise ValueError('Unexpected condition label')
    if not (eye.J_Group.eq('masking') == eye.Media.str.contains('마스킹')).all():
        raise ValueError('Condition labels and stimulus names disagree')
    # This fixed membership reproduces the retained sample; it does not infer
    # or retrospectively invent an acquisition-quality exclusion threshold.
    eye = eye.loc[eye.ID.isin(spec['eye_ids'])].copy()
    metric_columns = spec['eye_metric_columns']
    if len(metric_columns) != 48 or not set(metric_columns).issubset(eye.columns):
        raise ValueError('Expected 48 original export fields')
    rows = []
    for metric in metric_columns:
        values = pd.to_numeric(eye[metric], errors='coerce')
        for (_, rec), value in zip(eye.iterrows(), values):
            rows.append(dict(ID=rec.ID, Group=str(rec.Group_behavior).upper(),
                             Condition={'masking': 'Faceless', 'control': 'Standard'}[rec.J_Group],
                             Media=rec.Media, Metric=metric, Value=value))
    eye_long = pd.DataFrame(rows)
    survey_long.to_csv(output / 'survey_long.csv', index=False)
    eye_long.to_csv(output / 'eye_long.csv', index=False)
    selected[['Group_behavior', 'Q_123', 'Q_124']].to_csv(output / 'cues.csv', index=False)
    report = dict(source_sha256=spec['source_sha256'],
                  survey_participants=int(survey_long.ID.nunique()),
                  eye_participants=int(eye_long.ID.nunique()),
                  survey_rows=len(survey_long), eye_rows=len(eye_long),
                  all_rating_fields_missing_excluded=int(answered.eq(0).sum()),
                  eye_membership_basis=spec['eye_membership_basis'],
                  note='Trial indexes identify retained questionnaire fields; they do not resolve the separately deferred administered-trial count.')
    (args.output_root / 'preparation_report.json').write_text(json.dumps(report, indent=2))
    print(json.dumps({k: report[k] for k in ['survey_participants', 'eye_participants', 'survey_rows', 'eye_rows']}))


if __name__ == '__main__':
    main()
