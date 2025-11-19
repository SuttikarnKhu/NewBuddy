// This is a generated file - do not edit.
//
// Generated from speech_service.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;

import 'speech_service.pb.dart' as $0;

export 'speech_service.pb.dart';

@$pb.GrpcServiceName('speech.SpeechService')
class SpeechServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  SpeechServiceClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseStream<$0.AudioResponse> processSpeech(
    $async.Stream<$0.AudioRequest> request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(_$processSpeech, request, options: options);
  }

  // method descriptors

  static final _$processSpeech =
      $grpc.ClientMethod<$0.AudioRequest, $0.AudioResponse>(
          '/speech.SpeechService/ProcessSpeech',
          ($0.AudioRequest value) => value.writeToBuffer(),
          $0.AudioResponse.fromBuffer);
}

@$pb.GrpcServiceName('speech.SpeechService')
abstract class SpeechServiceBase extends $grpc.Service {
  $core.String get $name => 'speech.SpeechService';

  SpeechServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.AudioRequest, $0.AudioResponse>(
        'ProcessSpeech',
        processSpeech,
        true,
        true,
        ($core.List<$core.int> value) => $0.AudioRequest.fromBuffer(value),
        ($0.AudioResponse value) => value.writeToBuffer()));
  }

  $async.Stream<$0.AudioResponse> processSpeech(
      $grpc.ServiceCall call, $async.Stream<$0.AudioRequest> request);
}
