"""Provider protocol tests using mocked HTTP responses; no live AI claims."""
import importlib.util
import json
import os
import unittest
from unittest.mock import patch, Mock
from io import BytesIO
from pathlib import Path
spec = importlib.util.spec_from_file_location('bridge', Path(__file__).with_name('soul_ai_server.py'))
bridge = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bridge)
class Response(BytesIO):
    def __enter__(self): return self
    def __exit__(self, *args): self.close()
class Tests(unittest.TestCase):
    def test_temporary_overload_retries_and_accepts_real_protocol_reply(self):
        from urllib.error import HTTPError
        score = {'understanding': 2, 'validation': 2, 'support': 1, 'unsafe': False, 'feedback': 'An được lắng nghe.'}
        reply = Response(json.dumps({'candidates': [{'finishReason': 'STOP', 'content': {'parts': [{'text': json.dumps(score)}]}}]}).encode())
        overload = HTTPError('https://provider.test', 503, 'unavailable', {}, BytesIO(b'private-provider-body'))
        with patch.dict(os.environ, {'SOUL_AI_PROVIDER': 'gemini', 'SOUL_AI_MODEL': 'gemini-3.8-flash', 'GOOGLE_API_KEY': 'fixture-google-key'}), patch.object(bridge, 'urlopen', side_effect=[overload, reply]) as http, patch.object(bridge.time, 'sleep') as delay:
            result = bridge.grade(bridge.MEMORIES['drawing'], 'Em không có lỗi.')
        self.assertEqual(result['scores']['validation'], 2)
        self.assertEqual(http.call_count, 2)
        delay.assert_called_once_with(0.5)

    def test_retry_is_bounded_and_does_not_retry_quota_or_bad_request(self):
        from urllib.error import HTTPError
        from urllib.request import Request
        errors = [HTTPError('https://provider.test', 503, 'unavailable', {}, BytesIO(b'private')) for _ in range(3)]
        with patch.object(bridge, 'urlopen', side_effect=errors) as http, patch.object(bridge.time, 'sleep') as delay:
            with self.assertRaises(HTTPError) as context:
                bridge.fetch_provider_json(Request('https://provider.test'))
        self.assertEqual(http.call_count, 3)
        self.assertEqual(delay.call_count, 2)
        context.exception.close()
        for code in [400, 401, 403, 429]:
            error = HTTPError('https://provider.test', code, 'private', {}, BytesIO(b'private'))
            with patch.object(bridge, 'urlopen', side_effect=error) as http, patch.object(bridge.time, 'sleep') as delay:
                with self.assertRaises(HTTPError) as context:
                    bridge.fetch_provider_json(Request('https://provider.test'))
            self.assertEqual(http.call_count, 1)
            delay.assert_not_called()
            context.exception.close()

    def test_missing_gemini_key_has_actionable_reason(self):
        with patch.dict(os.environ, {'SOUL_AI_PROVIDER': 'gemini', 'SOUL_AI_MODEL': 'gemini-3.8-flash', 'GOOGLE_API_KEY': '', 'GEMINI_API_KEY': ''}), patch.object(bridge, 'read_settings', return_value={'provider': 'gemini', 'api_key': ''}):
            with self.assertRaises(bridge.GradingUnavailable) as context:
                bridge.grade(bridge.MEMORIES['drawing'], 'Em không có lỗi.')
            self.assertEqual(bridge.failure_reason(context.exception), 'missing_api_key')

    def test_provider_errors_are_fixed_codes_without_provider_secrets(self):
        from urllib.error import HTTPError, URLError
        cases = [(HTTPError('https://example.test?key=fixture-secret', code, 'private provider message', {}, BytesIO(b'fixture-secret')), reason) for code, reason in [(400, 'provider_request_invalid'), (401, 'invalid_api_key'), (403, 'api_access_denied'), (404, 'model_not_found'), (429, 'quota_exceeded'), (500, 'provider_unavailable')]]
        cases += [(TimeoutError('fixture-secret'), 'timeout'), (URLError('fixture-secret'), 'network_error'), (ValueError('fixture-secret'), 'invalid_ai_response')]
        for error, expected in cases:
            self.assertEqual(bridge.failure_reason(error), expected)
            if isinstance(error, HTTPError):
                error.close()

    def test_post_returns_reason_and_request_id_without_fabricating_score(self):
        from urllib.error import HTTPError
        data = json.dumps({'memory_id': 'drawing', 'text': 'Em không có lỗi.', 'request_id': 'fixture-error'}).encode()
        for error, expected in [(bridge.GradingUnavailable('missing_api_key'), 'missing_api_key'), (HTTPError('https://provider.test?key=fixture-secret', 429, 'fixture-secret', {}, BytesIO(b'fixture-secret')), 'quota_exceeded')]:
            handler = bridge.Handler.__new__(bridge.Handler)
            handler.path = '/comfort'
            handler.headers = {'Content-Length': str(len(data))}
            handler.rfile = BytesIO(data)
            handler.respond = Mock()
            with patch.object(bridge, 'grade', side_effect=error), patch('builtins.print'):
                handler.do_POST()
            status, value = handler.respond.call_args.args
            self.assertEqual(status, 503)
            self.assertEqual(value, {'error': 'ai_unavailable', 'reason': expected, 'request_id': 'fixture-error'})
            self.assertNotIn('fixture-secret', json.dumps(value))
            self.assertNotIn('scores', value)

    def test_health_reports_missing_key_without_exposing_configuration(self):
        handler = bridge.Handler.__new__(bridge.Handler)
        handler.path = '/health'
        handler.respond = Mock()
        with patch.dict(os.environ, {'SOUL_AI_PROVIDER': '', 'SOUL_AI_MODEL': '', 'GOOGLE_API_KEY': '', 'GEMINI_API_KEY': ''}), patch.object(bridge, 'read_settings', return_value={'provider': 'gemini', 'model': 'gemini-3.8-flash', 'api_key': '', 'opencode_api_key': 'fixture-secret'}):
            handler.do_GET()
        status, value = handler.respond.call_args.args
        self.assertEqual(status, 200)
        self.assertFalse(value['configured'])
        self.assertEqual(value['reason'], 'missing_api_key')
        self.assertNotIn('fixture-secret', json.dumps(value))

    def test_gemini_request_uses_header_and_structured_output(self):
        score = {'understanding': 2, 'validation': 2, 'support': 1, 'unsafe': False, 'feedback': 'An được lắng nghe.'}
        def fake(request, timeout):
            self.assertEqual(request.full_url, 'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent')
            self.assertEqual(request.get_header('X-goog-api-key'), 'fixture-google-key')
            self.assertNotIn('Authorization', request.headers)
            body = json.loads(request.data)
            self.assertEqual(body['generationConfig']['responseFormat']['text']['schema'], bridge.SCHEMA)
            self.assertEqual(body['generationConfig']['responseFormat']['text']['mimeType'], 'APPLICATION_JSON')
            self.assertEqual(body['generationConfig']['thinkingConfig']['thinkingLevel'], 'low')
            self.assertIn('player_words', body['contents'][0]['parts'][0]['text'])
            # Thought text must never be mistaken for the grading answer.
            return Response(json.dumps({'candidates': [{'finishReason': 'STOP', 'content': {'parts': [{'thought': True, 'text': 'not JSON'}, {'text': json.dumps(score)}]}}]}).encode())
        with patch.dict(os.environ, {'SOUL_AI_PROVIDER': 'gemini', 'SOUL_AI_MODEL': 'gemini-3.8-flash', 'GOOGLE_API_KEY': 'fixture-google-key'}), patch.object(bridge, 'urlopen', fake):
            result = bridge.grade(bridge.MEMORIES['drawing'], 'Em không có lỗi.')
            self.assertEqual(result['scores']['validation'], 2)
            self.assertEqual(result['source'], 'ai')

    def test_gemini_blocked_and_truncated_outputs_cannot_grade(self):
        for result in [{'promptFeedback': {'blockReason': 'SAFETY'}}, {'candidates': [{'finishReason': 'MAX_TOKENS', 'content': {'parts': [{'text': '{}'}]}}]}]:
            with self.subTest(result=result), patch.dict(os.environ, {'SOUL_AI_PROVIDER': 'gemini', 'SOUL_AI_MODEL': 'gemini-3.8-flash', 'GOOGLE_API_KEY': 'fixture-google-key'}), patch.object(bridge, 'urlopen', return_value=Response(json.dumps(result).encode())):
                with self.assertRaises(RuntimeError): bridge.grade(bridge.MEMORIES['fear'], 'x')

    def test_gemini_cannot_reuse_opencode_key(self):
        config = {'provider': 'opencode', 'api_key': 'fixture-opencode-key'}
        with patch.dict(os.environ, {'SOUL_AI_PROVIDER': 'gemini', 'SOUL_AI_MODEL': 'gemini-3.8-flash', 'GOOGLE_API_KEY': '', 'GEMINI_API_KEY': ''}), patch.object(bridge, 'read_settings', return_value=config), patch.object(bridge, 'urlopen') as http:
            with self.assertRaises(RuntimeError): bridge.grade(bridge.MEMORIES['fear'], 'x')
            http.assert_not_called()

    def test_opencode_request_and_valid_json(self):
        result = {'understanding': 2, 'validation': 2, 'support': 1, 'unsafe': False, 'feedback': 'An được lắng nghe.'}
        def fake(request, timeout):
            self.assertEqual(request.full_url, 'https://opencode.ai/zen/v1/chat/completions')
            body = json.loads(request.data)
            self.assertEqual(body['model'], 'mimo-v2.5-free')
            self.assertIn('player_words', body['messages'][1]['content'])
            return Response(json.dumps({'choices':[{'message':{'content':json.dumps(result)}}]}).encode())
        with patch.dict(os.environ, {'SOUL_AI_PROVIDER':'opencode','SOUL_AI_MODEL':'mimo-v2.5-free','OPENCODE_API_KEY':'fixture-not-a-real-key'}), patch.object(bridge, 'urlopen', fake):
            self.assertEqual(bridge.grade(bridge.MEMORIES['fear'], 'Em không có lỗi.' )['scores']['validation'], 2)
    def test_invalid_scores_fail_closed(self):
        invalid = {'understanding':True,'validation':2,'support':2,'unsafe':False,'feedback':'x'}
        with patch.dict(os.environ, {'SOUL_AI_PROVIDER':'local','SOUL_AI_MODEL':'fixture'}), patch.object(bridge, 'urlopen', return_value=Response(json.dumps({'choices':[{'message':{'content':json.dumps(invalid)}}]}).encode())):
            with self.assertRaises(ValueError): bridge.grade(bridge.MEMORIES['drawing'], 'x')
    def test_missing_key_does_not_grade(self):
        with patch.dict(os.environ, {'SOUL_AI_PROVIDER':'opencode','SOUL_AI_MODEL':'mimo-v2.5-free','OPENCODE_API_KEY':''}), patch.object(bridge, 'read_settings', return_value={}):
            with self.assertRaises(RuntimeError): bridge.grade(bridge.MEMORIES['isolation'], 'x')
if __name__ == '__main__': unittest.main()
