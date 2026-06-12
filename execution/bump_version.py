import os
import re
import sys

def bump_version(new_version):
    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    
    # 1. Update backend/version.py
    backend_version_path = os.path.join(project_root, 'backend', 'version.py')
    with open(backend_version_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    content = re.sub(r'APP_VERSION = ".*?"', f'APP_VERSION = "{new_version}"', content)
    with open(backend_version_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"Updated backend/version.py to {new_version}")

    # 2. Update frontend/pubspec.yaml
    pubspec_path = os.path.join(project_root, 'frontend', 'pubspec.yaml')
    with open(pubspec_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    match = re.search(r'version: (.*?)\+(\d+)', content)
    if match:
        old_version = match.group(1)
        old_build = int(match.group(2))
        new_build = old_build + 1
        new_pubspec_version = f"version: {new_version}+{new_build}"
        content = re.sub(r'version: .*?\+\d+', new_pubspec_version, content)
        with open(pubspec_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Updated frontend/pubspec.yaml to {new_version}+{new_build}")
    else:
        print("Could not find version in pubspec.yaml")

    # 3. Update frontend/lib/core/app_version.dart
    app_version_path = os.path.join(project_root, 'frontend', 'lib', 'core', 'app_version.dart')
    if os.path.exists(app_version_path):
        with open(app_version_path, 'r', encoding='utf-8') as f:
            content = f.read()
        content = re.sub(r"const String kAppVersion = '.*?';", f"const String kAppVersion = '{new_version}';", content)
        with open(app_version_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Updated frontend/lib/core/app_version.dart to {new_version}")
    else:
        print("app_version.dart non trovato, salto...")

    print("\nTutti i file di versione sono stati aggiornati correttamente!")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Uso: python bump_version.py <nuova_versione>")
        print("Esempio: python bump_version.py 1.9.5")
        sys.exit(1)
    
    bump_version(sys.argv[1])
