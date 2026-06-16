import os

def refactor_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    new_content = ""
    idx = 0
    length = len(content)
    changed = False

    while idx < length:
        # Trova il pattern '.withOpacity('
        pos = content.find('.withOpacity(', idx)
        if pos == -1:
            new_content += content[idx:]
            break

        # Aggiungi il testo fino a prima di '.withOpacity('
        new_content += content[idx:pos]
        
        # Ora cerchiamo la parentesi chiusa bilanciata
        start_paren = pos + len('.withOpacity(')
        paren_count = 1
        current_pos = start_paren
        
        while current_pos < length and paren_count > 0:
            char = content[current_pos]
            if char == '(':
                paren_count += 1
            elif char == ')':
                paren_count -= 1
            current_pos += 1

        if paren_count == 0:
            # Abbiamo trovato la parentesi chiusa bilanciata
            expr = content[start_paren:current_pos - 1]
            new_content += f'.withValues(alpha: {expr})'
            idx = current_pos
            changed = True
        else:
            # Qualcosa è andato storto, lasciamo così com'è
            new_content += '.withOpacity('
            idx = start_paren

    if changed:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Refactored: {filepath}")

def main():
    lib_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'frontend', 'lib'))
    for root, dirs, files in os.walk(lib_path):
        for file in files:
            if file.endswith('.dart'):
                refactor_file(os.path.join(root, file))

if __name__ == '__main__':
    main()
