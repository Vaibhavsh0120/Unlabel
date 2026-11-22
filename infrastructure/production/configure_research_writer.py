"""Grant the source importer find/insert access to research evidence, without delete/update."""

import json
import shlex
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = """const connection=new Mongo('mongodb://127.0.0.1:27017');
connection.getDB('admin').auth(process.env.MONGO_INITDB_ROOT_USERNAME,process.env.MONGO_INITDB_ROOT_PASSWORD);
const evidence=connection.getDB('unlabel_evidence');
const role={role:'research_append',privileges:[{resource:{db:'unlabel_evidence',collection:'research_observations'},actions:['find','insert']}],roles:[]};
if(evidence.getRole(role.role)) evidence.updateRole(role.role,{privileges:role.privileges,roles:[]});
else evidence.createRole(role);
const writer=evidence.getUser('unlabel_writer');
if(!writer) throw new Error('Existing importer user is absent');
if(!writer.roles.some(r=>r.role===role.role && r.db==='unlabel_evidence')) {
 evidence.updateUser(writer.user,{roles:[...writer.roles,{role:role.role,db:'unlabel_evidence'}]});
}
print('Research evidence writer ready: find/insert only.');
"""


def main():
    resources = json.loads((ROOT / "infrastructure/production/resources.json").read_text())
    container = shlex.quote(resources["databases"]["evidence"])
    result = subprocess.run(
        ["ssh", "-o", "RemoteCommand=none", "-o", "RequestTTY=no", "-o", "BatchMode=yes",
         "Volcanica", f"docker exec -i {container} mongosh --quiet --nodb --file /dev/stdin"],
        input=SCRIPT, text=True, capture_output=True, timeout=30,
    )
    if result.returncode:
        raise SystemExit("Research role setup failed; private diagnostics withheld.")
    print("Research evidence writer ready: find/insert only.")


if __name__ == "__main__":
    main()
