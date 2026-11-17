import unittest

from app import is_http_url


class HttpUrlTests(unittest.TestCase):
    def test_accepts_kubernetes_and_other_websites(self):
        self.assertTrue(is_http_url("https://kubernetes.io/docs/home/"))
        self.assertTrue(is_http_url("https://kubernetes.io/docs/tasks/debug/"))
        self.assertTrue(is_http_url("https://example.com/kubernetes"))

    def test_rejects_non_http_schemes_and_missing_hosts(self):
        self.assertFalse(is_http_url("javascript:alert(1)"))
        self.assertFalse(is_http_url("file:///etc/passwd"))
        self.assertFalse(is_http_url("https:///missing-host"))


if __name__ == "__main__":
    unittest.main()
