import csv
import math

def read_test_csv(file_path):
    rows = []
    with open(file_path, newline='', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for r in reader:
            row = {k: (v.strip() if isinstance(v, str) else v) for k, v in r.items()}
            if 'BSSID' in row and row['BSSID'] is not None:
                row['BSSID'] = str(row['BSSID']).strip().lower()
            if 'Location' in row and row['Location'] is not None:
                row['Location'] = str(row['Location']).strip().lower()
            
            for num_key in ['Bandwidth MHz', 'Estimated Distance m', 'Frequency MHz', 'Signal Strength dBm']:
                if num_key in row and row[num_key] not in (None, ''):
                    try:
                        if '.' in row[num_key]:
                            val = float(row[num_key])
                        else:
                            val = int(row[num_key])
                        if isinstance(val, float) and (math.isfinite(val) is False):
                            raise ValueError
                        row[num_key] = val
                    except Exception:
                        pass
            rows.append(row)
    return rows
