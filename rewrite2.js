const fs = require('fs');
const path = 'C:/dev/SafeArms/frontend/lib/screens/anomaly/anomaly_detection_screen.dart';
let content = fs.readFileSync(path, 'utf8');

if (!content.includes('../../widgets/base_modal_widget.dart')) {
    content = content.replace(
        'import \'../../widgets/anomaly_card_widget.dart\';',
        'import \'../../widgets/anomaly_card_widget.dart\';\nimport \'../../widgets/base_modal_widget.dart\';'
    );
}

const classStart = content.indexOf('class _AnomalyDetailModal extends StatefulWidget');

const newClass = fs.readFileSync('C:/Users/mpaci/AppData/Roaming/Code/User/workspaceStorage/f291fe5a4cf3dd5bde24db32e60b93a1/GitHub.copilot-chat/chat-session-resources/9b2f6c51-70fd-4e03-8422-49be24cd06da/call_MHxrZkFrRXRyZ21yTE5YbnkwUnE__vscode-1777816910992/content.txt', 'utf8');

let replacementText = newClass;
if (replacementText.includes('class _AnomalyDetailModal extends StatefulWidget')) {
    replacementText = replacementText.substring(replacementText.indexOf('class _AnomalyDetailModal extends StatefulWidget'));
}

replacementText = replacementText.replace(/[\\\]+$/, '').trim();

content = content.slice(0, classStart) + replacementText + '\n';

fs.writeFileSync(path, content, 'utf8');
console.log('Replaced successfully');