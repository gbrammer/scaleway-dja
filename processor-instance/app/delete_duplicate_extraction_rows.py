#!/usr/bin/env python

from grizli.aws import db

dups = db.SQL("select * from (select file, root, count(*) from nirspec_extractions group by file, root order by count(file)) counts where count > 1")

if len(dups) > 0:
    dups.pprint_all()
    
    dup_roots = db.quoted_strings(np.unique(dups['root']))
    
    db.execute(f"""
DELETE FROM nirspec_extractions a
USING nirspec_extractions b
WHERE
    a.ctime < b.ctime AND a.file = b.file AND a.root = b.root
    AND a.root in ({','.join(dup_roots)})
    AND b.root in ({','.join(dup_roots)})
""")

else:
    print("No duplicate entries found")
