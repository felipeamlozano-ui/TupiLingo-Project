import os, ast

def inspect_backend_tests():
    backend_dir = r'c:\Users\Felipe\Desktop\TupiLingo\backend'
    test_files = []
    for root, dirs, files in os.walk(backend_dir):
        if 'venv' in root: continue
        for f in files:
            if f.startswith('test_') or f.endswith('_test.py') or f == 'tests.py':
                test_files.append(os.path.join(root, f))
    
    print(f"Total test files in backend: {len(test_files)}")
    for tf in sorted(test_files):
        rel = os.path.relpath(tf, backend_dir)
        with open(tf, 'r', encoding='utf-8', errors='ignore') as fp:
            content = fp.read()
        try:
            tree = ast.parse(content)
            test_cases = [node.name for node in ast.walk(tree) if isinstance(node, ast.ClassDef) and 'Test' in node.name]
            test_methods = [node.name for node in ast.walk(tree) if isinstance(node, ast.FunctionDef) and node.name.startswith('test_')]
            print(f"  {rel:45s} | Classes: {len(test_cases):2d} | Test Methods: {len(test_methods):2d}")
        except Exception as e:
            print(f"  {rel:45s} | Parse Error: {e}")

if __name__ == '__main__':
    inspect_backend_tests()
