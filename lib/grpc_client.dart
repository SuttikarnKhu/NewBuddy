import 'package:grpc/grpc.dart';
import 'package:newbuddy/src/generated/speech_service.pbgrpc.dart';
import 'package:logging/logging.dart';

class GrpcClient {
  late ClientChannel _channel;
  late SpeechServiceClient _stub;
  final _log = Logger('GrpcClient');

  String serverCrt = """-----BEGIN CERTIFICATE-----
MIIFLjCCAxagAwIBAgIUdeQZg1IFOgh+gcHm6/rCiFUEK9gwDQYJKoZIhvcNAQEL
BQAwGTEXMBUGA1UEAwwOYXBpLmJ1ZGR5LnJlc3QwHhcNMjUxMTEzMDI0MjM3WhcN
MjYxMTEzMDI0MjM3WjAZMRcwFQYDVQQDDA5hcGkuYnVkZHkucmVzdDCCAiIwDQYJ
KoZIhvcNAQEBBQADggIPADCCAgoCggIBALdBq4Pcs6pBO9fWZ08Tj8hI2gMjmlfZ
tNhEVuleUIyqSMfZ21cdOjrNqyP0d8ajp1qRVZ0YYhXKfy9ZZ/WyJIC5ZdeKCW8s
mlBCuZvIkUpVcxTURZr+NyesB4gqWDQUFG4MUWsiUk3KO3/1wiN5IhyjX/ApJPLd
+CIMnrMIaqXUfZO344vGQQfKgzBY0jxOQhINoXVYZcSxzDJhV0Zd+13PDmJRAMYb
IoaiZRklsvcyx0B4nE4PKdeHHcBNKULpH5AYu2ZH+rT3AqCZMxDB79740Ykt42/N
RS6tQr8w6OljHM0+/Nt98cn+JSyikuyrOX//mVfD8zpvt6+CufsblZHIJxOWRBea
0C+IG0/4aDamEQkanedNvw/oDwQBlmw8ie1ezaG8C30++tMrxZSZ+G+DACc622Dj
pNqS93eTsbHT8S25M0tU27RLeqZcydhI0HCoNXq4diG/EX3jbyJaI3gvQvwDQVSU
1JKXosKBmbsaaqUy759aEU5p8sRCASXLS2nBM8P5/s3AjMaO5tGkt+ti/lTpe/gq
C1QToWwRfJiriscpy/9wVFfzSitPwPmB3skLvB6uFwFmvtcOycLZaXu9qfiG3h6N
sdgIj49G8OQe8Lq+eEIpLTmybmjciAr7T85R7yZtT7Lt/fO9naVR/3GILOtK4R/2
2Id2U4vnIyi7AgMBAAGjbjBsMB0GA1UdDgQWBBSGpDPyAv+HD49S7UeN95PocTSh
ZDAfBgNVHSMEGDAWgBSGpDPyAv+HD49S7UeN95PocTShZDAPBgNVHRMBAf8EBTAD
AQH/MBkGA1UdEQQSMBCCDmFwaS5idWRkeS5yZXN0MA0GCSqGSIb3DQEBCwUAA4IC
AQBbY7ePfZKqHp37vyYkaTWuaxwuhnwhkJymWuSgjbeMT5Nqm4kIf5YJLx6yVPrW
ay6tOWhpD3CLx8826VKvJ15iwj4d78Q0p/J9HF5+67zcFSlkRpH27i/1pdZ1Xx4m
tWAAGyzuhs3TW6xIzTvRbhymElU0M4aTkJJP83CtJDswTAzBkhnqLPAyBJM9bXpf
6O4y3DvNlQaA/te20RoGAnPAkdyCmnhuPBRTMCHd+zcUIsz1ut4qlLfbmdHBQQyG
CZFX2JPuetPhAZtbKKYtOhF0nAiMO/k35sfEB6ucxuRJR2TqR2CXieXZvGaEVwG/
7g3vhavuOhfowX+pQmU+JgMZrqvzqXFfWl5hCxVO4VXZWx93SrxSr6SF7Apa8JPI
uMWO/dDZOtW8WBzjkV8tk6sQUIQMjjJgx0vPkEKjQNlgJdvF3nNKrH2VwzYcXAJo
bVsA7OJ20EYqG2of+HXcnmaWUJrkFf9rQjrgjYO64CAYDUCSTMXM8fkKxRxIuHba
xvtJsr8tZg1neB9HrdfPHJbImSUiezMQKrplqthl7ty5t7di0Erw+Q34pmuT0Ky4
6iO1whAy94EVElpfCkEf9zV+oFaxR7mX/A19hgBLiONKI3HuSFCk+tDvyRcGMdRE
o8qBuh3U6r8u0DVPSIJdr3uy/cGzl8jTsU4DYwJLTCK7Rw==
-----END CERTIFICATE-----""";

  GrpcClient() {
    final credentials = ChannelCredentials.secure(
      certificates: serverCrt.codeUnits,
      authority: 'api.buddy.rest',
    );

    _channel = ClientChannel(
      'api.buddy.rest',
      port: 50051,
      options: ChannelOptions(credentials: credentials),
    );
    _stub = SpeechServiceClient(_channel);
    _log.info('gRPC client initialized');
  }

  Future<AudioResponse> processSpeech(List<int> audioData, int sampleRate) async {
    final request = AudioRequest(audioData: audioData, sampleRate: sampleRate);
    _log.info('Sending audio data to server...');
    try {
      final response = await _stub.processSpeech(request);
      _log.info('Received response: Transcribed text - ${response.transcribedText}, LLM response - ${response.llmResponse}');
      return response;
    } catch (e) {
      _log.severe('Error calling gRPC service: $e');
      rethrow;
    }
  }

  Future<void> shutdown() async {
    _log.info('Shutting down gRPC channel');
    await _channel.shutdown();
  }
}
