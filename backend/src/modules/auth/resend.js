export function createResendEmailSender({ apiKey, fromEmail }) {
  return async ({ to, otp }) => {
    if (!apiKey || !fromEmail) {
      const error = new Error('Email delivery is not configured.');
      error.code = 'EMAIL_NOT_CONFIGURED';
      throw error;
    }
    // Dynamic import keeps startup and isolated tests safe until `npm install`
    // has obtained the official Resend SDK.
    let Resend;
    try {
      ({ Resend } = await import('resend'));
    } catch (_error) {
      const error = new Error('Email delivery dependency is unavailable.');
      error.code = 'EMAIL_NOT_CONFIGURED';
      throw error;
    }
    const resend = new Resend(apiKey);
    const sendRequest = resend.emails.send({
        from: fromEmail,
        to: [to],
        subject: 'Your PriceShield verification code',
        html: `<p>Your PriceShield verification code is <strong>${otp}</strong>.</p><p>It expires in 5 minutes.</p>`,
      });
    const timeout = new Promise((_, reject) => setTimeout(
      () => reject(new Error('Resend request timed out.')),
      10000,
    ));
    let result;
    try {
      result = await Promise.race([sendRequest, timeout]);
    } catch (error) {
      const sendError = new Error('The verification email service is unreachable.');
      sendError.code = 'EMAIL_DELIVERY_FAILED';
      sendError.cause = error;
      throw sendError;
    }
    const { error } = result;
    if (error) {
      const sendError = new Error('The verification email could not be delivered.');
      sendError.code = 'EMAIL_DELIVERY_FAILED';
      throw sendError;
    }
  };
}

export function createDevelopmentOtpSender() {
  return async ({ to, otp }) => {
    console.warn(`[PriceShield development OTP] ${to}: ${otp}`);
  };
}
