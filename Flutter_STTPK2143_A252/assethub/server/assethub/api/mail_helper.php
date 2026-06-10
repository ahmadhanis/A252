<?php

require_once __DIR__ . "/../vendor/phpmailer/phpmailer/src/Exception.php";
require_once __DIR__ . "/../vendor/phpmailer/phpmailer/src/PHPMailer.php";
require_once __DIR__ . "/../vendor/phpmailer/phpmailer/src/SMTP.php";

use PHPMailer\PHPMailer\Exception;
use PHPMailer\PHPMailer\PHPMailer;

function assethub_build_verify_url(string $token, string $code): string
{
    $scheme = (!empty($_SERVER["HTTPS"]) && $_SERVER["HTTPS"] !== "off") ? "https" : "http";
    $host = $_SERVER["HTTP_HOST"] ?? "localhost";
    $scriptPath = $_SERVER["SCRIPT_NAME"] ?? "/assethub/api/register.php";
    $basePath = rtrim(str_replace("\\", "/", dirname($scriptPath)), "/");
    return $scheme . "://" . $host . $basePath . "/verify_registration.php?token=" . urlencode($token) . "&otp=" . urlencode($code);
}

function assethub_build_reset_url(string $token): string
{
    $scheme = (!empty($_SERVER["HTTPS"]) && $_SERVER["HTTPS"] !== "off") ? "https" : "http";
    $host = $_SERVER["HTTP_HOST"] ?? "localhost";
    $scriptPath = $_SERVER["SCRIPT_NAME"] ?? "/assethub/api/login.php";
    $basePath = rtrim(str_replace("\\", "/", dirname($scriptPath)), "/");
    return $scheme . "://" . $host . $basePath . "/reset_password.php?token=" . urlencode($token);
}

function assethub_send_verification_mail(
    string $recipientEmail,
    string $recipientName,
    string $otpCode,
    string $verificationUrl
): void {
    $mail = new PHPMailer(true);

    try {
        $mail->isSMTP();
        $mail->Host = "";
        $mail->SMTPAuth = true;
        $mail->Username = "";
        $mail->Password = "";
        $mail->SMTPSecure = PHPMailer::ENCRYPTION_SMTPS;
        $mail->Port = 465;
        $mail->Timeout = 20;
        $mail->SMTPOptions = [
            "ssl" => [
                "verify_peer" => false,
                "verify_peer_name" => false,
                "allow_self_signed" => true,
            ],
        ];
        $mail->CharSet = "UTF-8";

        $mail->setFrom("assethub@slumberjer.com", "AssetHub");
        $mail->addAddress($recipientEmail, $recipientName);
        $mail->isHTML(true);
        $mail->Subject = "Verify your AssetHub account";
        $mail->Body = "
            <div style='font-family: Arial, sans-serif; color: #0f172a; line-height: 1.6;'>
              <h2 style='margin-bottom: 8px;'>Welcome to AssetHub</h2>
              <p>Hello " . htmlspecialchars($recipientName, ENT_QUOTES, "UTF-8") . ",</p>
              <p>Your account has been created. To finish onboarding, please confirm your email using the OTP below or the verification link.</p>
              <p style='font-size: 28px; font-weight: bold; letter-spacing: 4px; margin: 16px 0;'>" . htmlspecialchars($otpCode, ENT_QUOTES, "UTF-8") . "</p>
              <p><a href='" . htmlspecialchars($verificationUrl, ENT_QUOTES, "UTF-8") . "' style='display: inline-block; background: #1d4ed8; color: #ffffff; padding: 12px 18px; border-radius: 8px; text-decoration: none;'>Verify Email</a></p>
              <p>If the button does not work, open this link:</p>
              <p><a href='" . htmlspecialchars($verificationUrl, ENT_QUOTES, "UTF-8") . "'>" . htmlspecialchars($verificationUrl, ENT_QUOTES, "UTF-8") . "</a></p>
              <p>This verification link expires in 24 hours.</p>
            </div>
        ";
        $mail->AltBody = "Welcome to AssetHub. Your OTP is $otpCode. Verify your account here: $verificationUrl";
        $mail->send();
    } catch (Exception $e) {
        throw new RuntimeException("Verification email could not be sent: " . $mail->ErrorInfo);
    }
}

function assethub_send_password_reset_mail(
    string $recipientEmail,
    string $recipientName,
    string $resetUrl
): void {
    $mail = new PHPMailer(true);

    try {
        $mail->isSMTP();
        $mail->Host = "";
        $mail->SMTPAuth = true;
        $mail->Username = "";
        $mail->Password = "";
        $mail->SMTPSecure = PHPMailer::ENCRYPTION_SMTPS;
        $mail->Port = 465;
        $mail->Timeout = 20;
        $mail->SMTPOptions = [
            "ssl" => [
                "verify_peer" => false,
                "verify_peer_name" => false,
                "allow_self_signed" => true,
            ],
        ];
        $mail->CharSet = "UTF-8";

        $mail->setFrom("assethub@slumberjer.com", "AssetHub");
        $mail->addAddress($recipientEmail, $recipientName);
        $mail->isHTML(true);
        $mail->Subject = "Reset your AssetHub password";
        $mail->Body = "
            <div style='font-family: Arial, sans-serif; color: #0f172a; line-height: 1.6;'>
              <h2 style='margin-bottom: 8px;'>Password Reset Request</h2>
              <p>Hello " . htmlspecialchars($recipientName, ENT_QUOTES, "UTF-8") . ",</p>
              <p>We received a request to reset your AssetHub password. Use the link below to choose a new password.</p>
              <p><a href='" . htmlspecialchars($resetUrl, ENT_QUOTES, "UTF-8") . "' style='display: inline-block; background: #1d4ed8; color: #ffffff; padding: 12px 18px; border-radius: 8px; text-decoration: none;'>Reset Password</a></p>
              <p>If the button does not work, open this link:</p>
              <p><a href='" . htmlspecialchars($resetUrl, ENT_QUOTES, "UTF-8") . "'>" . htmlspecialchars($resetUrl, ENT_QUOTES, "UTF-8") . "</a></p>
              <p>This reset link expires in 60 minutes.</p>
            </div>
        ";
        $mail->AltBody = "Reset your AssetHub password here: $resetUrl";
        $mail->send();
    } catch (Exception $e) {
        throw new RuntimeException("Password reset email could not be sent: " . $mail->ErrorInfo);
    }
}
