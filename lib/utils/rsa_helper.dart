import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';

class RSAHelper {
  static AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> generateKeyPair() {
    final keyGen = RSAKeyGenerator()
      ..init(ParametersWithRandom(
        RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
        _secureRandom(),
      ));
    final pair = keyGen.generateKeyPair();
    return AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>(
      pair.publicKey as RSAPublicKey,
      pair.privateKey as RSAPrivateKey,
    );
  }

  static SecureRandom _secureRandom() {
    final random = FortunaRandom();
    final seed = Uint8List.fromList(
        List.generate(32, (_) => Random.secure().nextInt(256)));
    random.seed(KeyParameter(seed));
    return random;
  }

  // Encrypt with recipient's public key
  static String encrypt(String plainText, RSAPublicKey publicKey) {
    final cipher = OAEPEncoding(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));
    final bytes = utf8.encode(plainText);
    // RSA 2048 can encrypt max 214 bytes with OAEP — chunk if needed
    final encrypted = _processInBlocks(cipher, Uint8List.fromList(bytes));
    return base64.encode(encrypted);
  }

  // Decrypt with own private key
  static String decrypt(String cipherText, RSAPrivateKey privateKey) {
    final cipher = OAEPEncoding(RSAEngine())
      ..init(false, PrivateKeyParameter<RSAPrivateKey>(privateKey));
    final bytes = base64.decode(cipherText);
    final decrypted = _processInBlocks(cipher, bytes);
    return utf8.decode(decrypted);
  }

  static Uint8List _processInBlocks(AsymmetricBlockCipher cipher, Uint8List input) {
    final output = <int>[];
    var offset = 0;
    while (offset < input.length) {
      final end = (offset + cipher.inputBlockSize < input.length)
          ? offset + cipher.inputBlockSize
          : input.length;
      output.addAll(cipher.process(input.sublist(offset, end)));
      offset = end;
    }
    return Uint8List.fromList(output);
  }

  // Serialize public key to string for sending over network
  static String publicKeyToString(RSAPublicKey key) {
    return jsonEncode({
      'modulus': key.modulus.toString(),
      'exponent': key.exponent.toString(),
    });
  }

  // Deserialize public key from string
  static RSAPublicKey publicKeyFromString(String str) {
    final map = jsonDecode(str);
    return RSAPublicKey(
      BigInt.parse(map['modulus']),
      BigInt.parse(map['exponent']),
    );
  }

  // Serialize private key
  static String privateKeyToString(RSAPrivateKey key) {
    return jsonEncode({
      'modulus': key.modulus.toString(),
      'exponent': key.privateExponent.toString(),
      'p': key.p.toString(),
      'q': key.q.toString(),
    });
  }

  // Deserialize private key
  static RSAPrivateKey privateKeyFromString(String str) {
    final map = jsonDecode(str);
    return RSAPrivateKey(
      BigInt.parse(map['modulus']),
      BigInt.parse(map['exponent']),
      BigInt.parse(map['p']),
      BigInt.parse(map['q']),
    );
  }
}
