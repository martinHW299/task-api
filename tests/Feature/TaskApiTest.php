<?php

namespace Tests\Feature;

use App\Enums\TaskStatus;
use App\Models\Task;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class TaskApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_it_shows_a_hello_message(): void
    {
        $res = $this->getJson('/api/hello');

        $res->assertOk()
            ->assertExactJson(['message' => 'Hello Azure devops!']);
    }

    public function test_it_lists_tasks(): void
    {
        Task::factory()->count(3)->create();

        $res = $this->getJson('/api/tasks');

        $res->assertOk()
            ->assertJsonStructure([
                'data' => [
                    '*' => ['id', 'title', 'description', 'status', 'due_at', 'created_at', 'updated_at']
                ],
                'links',
                'meta',
            ]);
    }

    public function test_it_creates_a_task_with_default_status(): void
    {
        $payload = [
            'title' => 'Buy groceries',
            'description' => 'Milk, eggs, bread',
            // status omitted on purpose
        ];

        $res = $this->postJson('/api/tasks', $payload);

        $res->assertCreated()
            ->assertJsonPath('data.title', 'Buy groceries')
            ->assertJsonPath('data.status', TaskStatus::Todo->value);

        $this->assertDatabaseHas('tasks', [
            'title' => 'Buy groceries',
            'status' => TaskStatus::Todo->value,
        ]);
    }

    public function test_it_validates_status_enum(): void
    {
        $payload = [
            'title' => 'Invalid task',
            'status' => 'not-a-real-status',
        ];

        $res = $this->postJson('/api/tasks', $payload);

        $res->assertUnprocessable()
            ->assertJsonValidationErrors(['status']);
    }

    public function test_it_shows_a_task(): void
    {
        $task = Task::factory()->create(['status' => TaskStatus::InProgress->value]);

        $res = $this->getJson("/api/tasks/{$task->id}");

        $res->assertOk()
            ->assertJsonPath('data.id', $task->id)
            ->assertJsonPath('data.status', TaskStatus::InProgress->value);
    }

    public function test_it_updates_a_task(): void
    {
        $task = Task::factory()->create(['status' => TaskStatus::Todo->value]);

        $payload = [
            'title' => 'Updated title',
            'status' => TaskStatus::Done->value,
        ];

        $res = $this->patchJson("/api/tasks/{$task->id}", $payload);

        $res->assertOk()
            ->assertJsonPath('data.title', 'Updated title')
            ->assertJsonPath('data.status', TaskStatus::Done->value);

        $this->assertDatabaseHas('tasks', [
            'id' => $task->id,
            'status' => TaskStatus::Done->value,
        ]);
    }

    public function test_it_deletes_a_task(): void
    {
        $task = Task::factory()->create();

        $res = $this->deleteJson("/api/tasks/{$task->id}");

        $res->assertNoContent();

        $this->assertDatabaseMissing('tasks', ['id' => $task->id]);
    }
}
