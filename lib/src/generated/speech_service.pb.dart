// This is a generated file - do not edit.
//
// Generated from speech_service.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class AudioRequest extends $pb.GeneratedMessage {
  factory AudioRequest({
    $core.List<$core.int>? audioData,
    $core.int? sampleRate,
  }) {
    final result = create();
    if (audioData != null) result.audioData = audioData;
    if (sampleRate != null) result.sampleRate = sampleRate;
    return result;
  }

  AudioRequest._();

  factory AudioRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AudioRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AudioRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'speech'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'audioData', $pb.PbFieldType.OY)
    ..aI(2, _omitFieldNames ? '' : 'sampleRate')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AudioRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AudioRequest copyWith(void Function(AudioRequest) updates) =>
      super.copyWith((message) => updates(message as AudioRequest))
          as AudioRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AudioRequest create() => AudioRequest._();
  @$core.override
  AudioRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AudioRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AudioRequest>(create);
  static AudioRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get audioData => $_getN(0);
  @$pb.TagNumber(1)
  set audioData($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAudioData() => $_has(0);
  @$pb.TagNumber(1)
  void clearAudioData() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get sampleRate => $_getIZ(1);
  @$pb.TagNumber(2)
  set sampleRate($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSampleRate() => $_has(1);
  @$pb.TagNumber(2)
  void clearSampleRate() => $_clearField(2);
}

class AudioResponse extends $pb.GeneratedMessage {
  factory AudioResponse({
    $core.List<$core.int>? audioData,
    $core.String? transcribedText,
    $core.String? llmResponse,
  }) {
    final result = create();
    if (audioData != null) result.audioData = audioData;
    if (transcribedText != null) result.transcribedText = transcribedText;
    if (llmResponse != null) result.llmResponse = llmResponse;
    return result;
  }

  AudioResponse._();

  factory AudioResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AudioResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AudioResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'speech'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'audioData', $pb.PbFieldType.OY)
    ..aOS(2, _omitFieldNames ? '' : 'transcribedText')
    ..aOS(3, _omitFieldNames ? '' : 'llmResponse')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AudioResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AudioResponse copyWith(void Function(AudioResponse) updates) =>
      super.copyWith((message) => updates(message as AudioResponse))
          as AudioResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AudioResponse create() => AudioResponse._();
  @$core.override
  AudioResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AudioResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AudioResponse>(create);
  static AudioResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get audioData => $_getN(0);
  @$pb.TagNumber(1)
  set audioData($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAudioData() => $_has(0);
  @$pb.TagNumber(1)
  void clearAudioData() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get transcribedText => $_getSZ(1);
  @$pb.TagNumber(2)
  set transcribedText($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTranscribedText() => $_has(1);
  @$pb.TagNumber(2)
  void clearTranscribedText() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get llmResponse => $_getSZ(2);
  @$pb.TagNumber(3)
  set llmResponse($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLlmResponse() => $_has(2);
  @$pb.TagNumber(3)
  void clearLlmResponse() => $_clearField(3);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
