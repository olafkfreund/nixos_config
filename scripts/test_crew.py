#!/usr/bin/env python3
import unittest
import unittest.mock
import sys
import os
import io
import shutil

# Make sure scripts directory is in path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import run_crew

class TestCrewOrchestrator(unittest.TestCase):
    
    def setUp(self):
        # Create a temp directory for safe test file outputs
        self.test_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "test_sandbox"))
        os.makedirs(self.test_dir, exist_ok=True)
        
    def tearDown(self):
        # Clean up temp test directory
        if os.path.exists(self.test_dir):
            shutil.rmtree(self.test_dir)

    def test_file_parsing_and_writing(self):
        sample_response = (
            "Here is the systemd configuration file:\n"
            "<file path=\"hosts/p620/test_service.nix\">\n"
            "{\n"
            "  systemd.services.test = {\n"
            "    description = \"Test Service\";\n"
            "  };\n"
            "}\n"
            "</file>\n"
            "Let me know if you need anything else!"
        )
        
        written = run_crew.parse_and_write_files(sample_response, self.test_dir)
        self.assertEqual(len(written), 1)
        
        expected_path = os.path.join(self.test_dir, "hosts/p620/test_service.nix")
        self.assertTrue(os.path.exists(expected_path))
        
        with open(expected_path, 'r') as f:
            content = f.read()
            self.assertIn("systemd.services.test", content)

    def test_path_traversal_protection(self):
        malicious_response = (
            "<file path=\"../../unsafe_outside.nix\">\n"
            "unsafe content\n"
            "</file>\n"
            "<file path=\"/tmp/absolute_unsafe.nix\">\n"
            "unsafe content\n"
            "</file>"
        )
        written = run_crew.parse_and_write_files(malicious_response, self.test_dir)
        self.assertEqual(len(written), 0)
        
        # Verify no files were created outside self.test_dir
        parent_dir = os.path.abspath(os.path.join(self.test_dir, ".."))
        unsafe_path = os.path.join(parent_dir, "unsafe_outside.nix")
        self.assertFalse(os.path.exists(unsafe_path))

    @unittest.mock.patch('subprocess.run')
    def test_syntax_validation_pass(self, mock_run):
        # Mock successful execution of nix-instantiate
        mock_res = unittest.mock.Mock()
        mock_res.returncode = 0
        mock_run.return_value = mock_res
        
        test_file = os.path.join(self.test_dir, "test.nix")
        with open(test_file, 'w') as f:
            f.write("{}")
            
        errors = run_crew.validate_syntax([test_file])
        self.assertEqual(len(errors), 0)
        mock_run.assert_called_once_with(["nix-instantiate", "--parse", test_file], capture_output=True, text=True)

    @unittest.mock.patch('subprocess.run')
    def test_syntax_validation_fail(self, mock_run):
        # Mock failed execution of nix-instantiate
        mock_res = unittest.mock.Mock()
        mock_res.returncode = 1
        mock_res.stderr = "error: undefined variable 'abc' at line 2"
        mock_run.return_value = mock_res
        
        test_file = os.path.join(self.test_dir, "bad.nix")
        with open(test_file, 'w') as f:
            f.write("abc")
            
        errors = run_crew.validate_syntax([test_file])
        self.assertEqual(len(errors), 1)
        self.assertIn("error: undefined variable", errors[0])

if __name__ == "__main__":
    unittest.main()
