<?php

declare(strict_types=1);

namespace App\Support;

/**
 * Birbaşa satışda yekun 0 olanda bağlanışa icazə qaydası.
 */
final class SessionCloseRules
{
    public static function counterZeroTotalError(
        int $itemCount,
        float $total,
        float $discount,
        float $bonusWalletUsed,
        int $bonusMinutesUsed,
        string $giftNote
    ): ?string {
        if ($itemCount <= 0 || round($total, 2) > 0) {
            return null;
        }

        $hasGiftDiscount = $discount > 0 && round($total, 2) <= 0;
        $bonusCovered = $bonusWalletUsed > 0.009 || $bonusMinutesUsed > 0;

        if ($hasGiftDiscount) {
            if (trim($giftNote) === '') {
                return 'Hədiyyə üçün qeyd yazın';
            }

            return null;
        }

        if ($bonusCovered) {
            return null;
        }

        return 'Səbətdə məhsul var — əvvəlcə səbəti təmizləyin və ya ödəniş alın';
    }
}
