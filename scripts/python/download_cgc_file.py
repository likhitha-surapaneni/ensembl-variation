"""
Version: 1.0 (2022-08-22)
"""

import argparse
import json
import re
import sys
import urllib.parse
import urllib.request
import os
from ftplib import FTP, error_perm


HOST = "ftp.ebi.ac.uk"
BASE_DIR = "/pub/databases/opentargets/platform"
EVIDENCE_DIR = "output/etl/json/evidence/sourceId=cancer_gene_census"
TARGET_DIR = "output/etl/json/targets"


def find_json_files(ftp, pathname):
    current = ftp.pwd()
    try:
        ftp.cwd(pathname)
    except error_perm as e:
        return  # file or private directory

    for name in ftp.nlst():
        if name.endswith(".json"):
            yield f"{pathname}/{name}"
        else:
            yield from find_json_files(ftp, f"{pathname}/{name}")

    ftp.cwd(current)


def walk_ftp(host, dirname):
    ftp = FTP(host)
    ftp.login()

    try:
        for filename in find_json_files(ftp, dirname):
            url = f"ftp://{host}{filename}"

            items = []
            with urllib.request.urlopen(url) as f:
                for line in f:
                    yield json.loads(line.decode("utf-8").rstrip())
    finally:
        ftp.quit()


def load_targets(host, dirname):
    targets = {}
    for obj in walk_ftp(host, dirname):
        targets[obj["id"]] = obj["approvedSymbol"]

    return targets


def main():
    parser = argparse.ArgumentParser(description="Retrieve target - disease "
                                                 "evidences from the Open "
                                                 "Targets Platform")
    parser.add_argument("-r", "--release",
                        default="latest",
                        help="release version (default: latest)")
    parser.add_argument("-d", "--dest_dir",
                        default=os.getcwd())
    args = parser.parse_args()

    release = args.release
    out_dir = args.dest_dir
    evidence_dir = f"{BASE_DIR}/{release}/{EVIDENCE_DIR}"
    target_dir = f"{BASE_DIR}/{release}/{TARGET_DIR}"

    output_file = os.path.join(out_dir, f"cgc_input_{release}.json")

    if release != "latest":
        if not re.fullmatch(r"\d\d\.\d\d", release):
            parser.exit(status=2,
                        message=f"error: invalid release version: "
                                f"{args.release}\n")
        elif release == "21.02":
            evidence_dir = f"{BASE_DIR}/21.02/output/ETL/evidences/succeeded/"
            evidence_dir += "sourceId=cancer_gene_census/"
            target_dir = f"{BASE_DIR}/21.02/output/ETL/targets/"
        elif float(release) >= 22.07:
            parser.exit(status=2,
                        message=f"error: release {args.release} "
                                f"not supported\n")

    sys.stderr.write(f"Fetching data from Open Target Platform "
                     f"(release: {release})\n")
    target2symbol = load_targets(HOST, target_dir)

    with open(output_file, "w") as f:
      for obj in walk_ftp(HOST, evidence_dir):
          try:
              disease_id = obj["diseaseId"]
          except KeyError:
              continue

          if obj["datasourceId"] != "cancer_gene_census":
              continue

          f.write(json.dumps(obj) + "\n")

if __name__ == '__main__':
    main()
