const fs = require('fs');

const path = 'src/scripts/seedDatabase.js';
let content = fs.readFileSync(path, 'utf8');

content = content.replace(/¦ Firearms               ¦ 12 \\(assigned to specific units\\)  ¦/, '¦ Firearms               ¦ \ (assigned to specific units)  ¦');
content = content.replace(/¦ Ballistic Profiles     ¦ 4                                ¦/, '¦ Ballistic Profiles     ¦ \                               ¦');

content = content.replace(/\\[FIREARMS\\] FIREARMS BY UNIT:[\\s\\S]*?+------------------------------------------------------------+/, \\\[FIREARMS] FIREARMS BY UNIT:
+------------------------------------------------------------+
¦ Unit        ¦ Firearms                                     ¦
+-------------+----------------------------------------------¦
¦ UNIT-HQ     ¦ \ firearms (AK-47 focus)            ¦
¦ UNIT-NYA    ¦ \ firearms (AK-47 focus)            ¦
¦ UNIT-KIM    ¦ \ firearms (AK-47 focus)            ¦
¦ UNIT-REM    ¦ \ firearms (AK-47 focus)            ¦
¦ UNIT-KIC    ¦ \ firearms (AK-47 focus)            ¦
¦ UNIT-PTS    ¦ \ firearms (AK-47 focus)            ¦
+------------------------------------------------------------+\\\);

fs.writeFileSync(path, content, 'utf8');
