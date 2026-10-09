/// Mobile payment channels and server-confirmed outcomes.
enum PaymentChannel { wechat, alipay }

enum PaymentProductKind { subscription, points }

enum PaymentOutcome { completed, processing, canceled, failed, unknown }
