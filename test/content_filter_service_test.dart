import 'package:flutter_test/flutter_test.dart';
import 'package:hpm_moderation/hpm_moderation.dart';

void main() {
  final filter = ContentFilterService.instance;

  group('ordinary Spanish that contains a blocked substring is allowed', () {
    const cleanMessages = [
      'Mi computadora no enciende',
      'Necesito reparar dos computadoras',
      'Tiene muy buena reputación',
      'La reputacion del técnico es excelente',
      'Hubo un retardo en la entrega',
      'Disculpe el retardo, llego en 10 minutos',
      'Ayudamos a los damnificados',
      'Voy a disputar el cobro',
      'Es una computación rápida',
      'Escribe tu dirección completa',
      'Las transferencias de llamadas no funcionan',
    ];

    for (final message in cleanMessages) {
      test('"$message"', () {
        expect(filter.checkMessage(message), isNull);
        expect(filter.isClean(message), isTrue);
        expect(filter.filterMessage(message), message);
      });
    }
  });

  group('real insults are still blocked', () {
    const blocked = {
      'eres una puta': 'puta',
      'PUTA': 'puta',
      'hijo de puta': 'puta',
      'qué mierda de servicio': 'mierda',
      'eres un cabrón': 'cabron',
      'pendejo': 'pendejo',
      'son unos pendejos': 'pendejos',
      'malparido': 'malparido',
      'culero!': 'culero',
      'fuck you': 'fuck',
      'you are a bitch.': 'bitch',
      'what a retard': 'retard',
    };

    blocked.forEach((message, keyword) {
      test('"$message" -> $keyword', () {
        expect(filter.checkMessage(message), keyword);
        expect(filter.isClean(message), isFalse);
      });
    });
  });

  group('deliberate obfuscation is still detected', () {
    const obfuscated = [
      'p u t a',
      'p.u.t.a',
      'P-U-T-A',
      'put@',
      'eres una put@',
      'mi3rda',
      'm i e r d a',
      'putaaaa',
      'mierdaaa',
      'púta',
      'cabrón',
      'kill yourself',
      'KILL   YOURSELF',
    ];

    for (final message in obfuscated) {
      test('"$message"', () {
        expect(filter.isClean(message), isFalse);
      });
    }
  });

  group('insults glued to a digit or symbol are still blocked', () {
    const glued = {
      'puta1': 'puta',
      'eres una puta0': 'puta',
      'mierda3': 'mierda',
      '@puta': 'puta',
      r'$mierda': 'mierda',
      'pendejo4': 'pendejo',
    };

    glued.forEach((message, keyword) {
      test('"$message" -> $keyword', () {
        expect(filter.checkMessage(message), keyword);
      });
    });
  });

  group('common inflections are blocked as whole words', () {
    const inflected = [
      'fuckin idiot',
      'hijueputas',
      'hijosdeputa',
      'qué pendejada',
      'retardado',
      'chingarte',
    ];

    for (final message in inflected) {
      test('"$message"', () {
        expect(filter.isClean(message), isFalse);
      });
    }
  });

  test('a long run of single letters is handled quickly', () {
    final message = 'a ' * 5000;
    final stopwatch = Stopwatch()..start();
    expect(filter.isClean(message), isTrue);
    expect(stopwatch.elapsedMilliseconds, lessThan(1000));
  });

  group('off-platform payment indicators', () {
    test('"transferencia" stays blocked as a whole word', () {
      expect(filter.checkMessage('hazme una transferencia'), 'transferencia');
      expect(filter.checkMessage('Transferencia bancaria'), 'transferencia');
    });

    test('"transferencia" is not matched inside another word', () {
      expect(filter.isClean('las transferencias de llamadas'), isTrue);
      expect(filter.isClean('retransferencia'), isTrue);
    });

    test('scam phrases are matched as whole-word sequences', () {
      expect(filter.checkMessage('please send money now'), 'send money');
      expect(filter.checkMessage('Envía dinero por Western Union'),
          'envia dinero');
      expect(filter.checkMessage('via wire transfer'), 'wire transfer');
    });

    test('phrase words on their own are allowed', () {
      expect(filter.isClean('send the photos'), isTrue);
      expect(filter.isClean('hay dinero en efectivo'), isTrue);
    });
  });

  group('filterMessage', () {
    test('masks a blocked word and keeps the rest', () {
      expect(filter.filterMessage('Eres una puta, de verdad'),
          'Eres una ****, de verdad');
    });

    test('masks accented and obfuscated forms in place', () {
      expect(filter.filterMessage('qué cabrón'), 'qué ******');
      expect(filter.filterMessage('eres una put@'), 'eres una ****');
      expect(filter.filterMessage('eres p u t a ya'), 'eres ******* ya');
    });

    test('masks every occurrence, not just the first', () {
      expect(filter.filterMessage('puta y puta'), '**** y ****');
    });

    test('does not mask ordinary words', () {
      const message = 'La computadora tiene buena reputación';
      expect(filter.filterMessage(message), message);
    });

    test('masks a multi-word phrase', () {
      expect(filter.filterMessage('please send money'), 'please **********');
    });
  });

  test('empty input is clean', () {
    expect(filter.checkMessage(''), isNull);
    expect(filter.filterMessage(''), '');
  });
}
