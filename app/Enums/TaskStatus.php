<?php

namespace App\Enums;

enum TaskStatus: string
{
    case Todo = 'todo';
    case InProgress = 'in_progress';
    case Done = 'done';

    public static function values(): array
    {
        return array_map(fn(self $s) => $s->value, self::cases());
    }
}
