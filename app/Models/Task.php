<?php

namespace App\Models;

use App\Enums\TaskStatus;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Task extends Model
{
    //Factory from Laravel 10+ uses "HasFactory" trait and "protected $model" property in the factory class, so no need to specify it here.
    use HasFactory;

    protected $fillable = [
        'title',
        'description',
        'status',
        'due_at',
    ];

    protected $casts = [
        'due_at' => 'datetime',
        'status' => TaskStatus::class, // Laravel will cast string <-> enum
    ];
}
