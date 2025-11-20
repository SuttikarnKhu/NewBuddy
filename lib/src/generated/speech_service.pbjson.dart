// This is a generated file - do not edit.
//
// Generated from speech_service.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use audioRequestDescriptor instead')
const AudioRequest$json = {
  '1': 'AudioRequest',
  '2': [
    {'1': 'audio_data', '3': 1, '4': 1, '5': 12, '10': 'audioData'},
    {'1': 'sample_rate', '3': 2, '4': 1, '5': 5, '10': 'sampleRate'},
    {'1': 'uid', '3': 3, '4': 1, '5': 9, '10': 'uid'},
    {'1': 'buddy_id', '3': 4, '4': 1, '5': 9, '10': 'buddyId'},
  ],
};

/// Descriptor for `AudioRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List audioRequestDescriptor = $convert.base64Decode(
    'CgxBdWRpb1JlcXVlc3QSHQoKYXVkaW9fZGF0YRgBIAEoDFIJYXVkaW9EYXRhEh8KC3NhbXBsZV'
    '9yYXRlGAIgASgFUgpzYW1wbGVSYXRlEhAKA3VpZBgDIAEoCVIDdWlkEhkKCGJ1ZGR5X2lkGAQg'
    'ASgJUgdidWRkeUlk');

@$core.Deprecated('Use audioResponseDescriptor instead')
const AudioResponse$json = {
  '1': 'AudioResponse',
  '2': [
    {'1': 'audio_data', '3': 1, '4': 1, '5': 12, '10': 'audioData'},
    {'1': 'transcribed_text', '3': 2, '4': 1, '5': 9, '10': 'transcribedText'},
    {'1': 'llm_response', '3': 3, '4': 1, '5': 9, '10': 'llmResponse'},
    {'1': 'trigger_call', '3': 4, '4': 1, '5': 8, '10': 'triggerCall'},
  ],
};

/// Descriptor for `AudioResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List audioResponseDescriptor = $convert.base64Decode(
    'Cg1BdWRpb1Jlc3BvbnNlEh0KCmF1ZGlvX2RhdGEYASABKAxSCWF1ZGlvRGF0YRIpChB0cmFuc2'
    'NyaWJlZF90ZXh0GAIgASgJUg90cmFuc2NyaWJlZFRleHQSIQoMbGxtX3Jlc3BvbnNlGAMgASgJ'
    'UgtsbG1SZXNwb25zZRIhCgx0cmlnZ2VyX2NhbGwYBCABKAhSC3RyaWdnZXJDYWxs');

const $core.Map<$core.String, $core.dynamic> SpeechServiceBase$json = {
  '1': 'SpeechService',
  '2': [
    {
      '1': 'ProcessSpeech',
      '2': '.speech.AudioRequest',
      '3': '.speech.AudioResponse',
      '4': {},
      '5': true,
      '6': true
    },
  ],
};

@$core.Deprecated('Use speechServiceDescriptor instead')
const $core.Map<$core.String, $core.Map<$core.String, $core.dynamic>>
    SpeechServiceBase$messageJson = {
  '.speech.AudioRequest': AudioRequest$json,
  '.speech.AudioResponse': AudioResponse$json,
};

/// Descriptor for `SpeechService`. Decode as a `google.protobuf.ServiceDescriptorProto`.
final $typed_data.Uint8List speechServiceDescriptor = $convert.base64Decode(
    'Cg1TcGVlY2hTZXJ2aWNlEkIKDVByb2Nlc3NTcGVlY2gSFC5zcGVlY2guQXVkaW9SZXF1ZXN0Gh'
    'Uuc3BlZWNoLkF1ZGlvUmVzcG9uc2UiACgBMAE=');
