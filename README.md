# 🕒 Delphi Cron Scheduler

**Delphi Cron Scheduler** — это класс на Delphi, реализующий планировщик заданий, работающий по принципу Unix-cron.  
Позволяет выполнять задачи по расписанию: каждую минуту, каждые N минут, в определённое время суток, по дням недели и т.д.

Поддерживает стандартный синтаксис cron-масок (`*`, `*/N`, `A-B`, `A,B,C`, `?`) и многопоточную работу через `TThread`.

---

## 🚀 Возможности

- Поддержка cron-масок формата:  

`* * * * *` → каждую минуту
`*/5 * * * *` → каждые 5 минут
`0 22 * * *` → каждый день в 22:00
`30 8 * * 1-5` → по будням в 8:30

Формат полей (слева направо):
Минуты | Часы | День месяца | Месяц | День недели

- Автоматический расчёт следующего времени запуска  
- Работа в отдельном потоке (`TCronThread`)
- Событие `OnExecute` вызывается в контексте главного потока (через `TThread.Queue`)
- Минимальные зависимости — только стандартная библиотека Delphi
- Совместимо с Delphi 11.x – Delphi 12+

---

## 📦 Установка

1. Склонировать репозиторий в Ваш проект `git clone https://git.north-side.ru/suslikstyle/cron-delphi.git`.
2. Добавьте `CronScheduler` в `uses` вашего модуля, где будет использоваться планировщик.
3. Создайте экземпляр `TCronThread` и добавьте задачу(и).

---

## 🧩 Пример использования

```pascal
uses
System.SysUtils, Vcl.Dialogs, CronScheduler;

var
	FCron: TCronThread;

begin
	// Создание планировщика
	FCron:= TCronThread.Create;
	FCron.OnExecute :=
	  procedure(Sender: TObject; const TaskName: string)
	  begin
		Writeln(Format('[%s] Выполнено: %s', [TimeToStr(Now), TaskName]));
	  end;

	// Добавление cron-задач
	FCron.AddTask('Каждую минуту', '* * * * *');
	FCron.AddTask('Каждые 3 минуты', '*/3 * * * *');
	FCron.AddTask('Каждые 5 минут', '*/5 * * * *');
	FCron.AddTask('Каждый день в 22:00', '0 22 * * *');

	Readln; // не даем завершиться

	// Завершение работы
	FCron.Terminate;
	FCron.WaitFor;
	FCron.Free;
end.
```

---

## ⚙️ Основные классы

#### `TCronTask`

*Отвечает за:*
- хранение cron-маски;
- разбор полей маски (`минуты`, `часы`, `дни`, `месяцы`, `дни`, `недели`);
- расчёт времени следующего выполнения (`GetNextTime`).

#### `TCronThread`

*Поток-планировщик:*
- содержит список `TCronTask`;
- вычисляет ближайшее время выполнения;
- ожидает нужный интервал с помощью события `TEvent`,
- вызывает `OnExecute` при наступлении задачи.


## 📄 Лицензия

Проект распространяется под MIT License.


## 👨‍💻 Автор

Delphi Cron Scheduler
Автор: [Konstantin](https://github.com/suslikstyle)
📧 Email: [suslik.style@gmail.com](mailto:suslik.style@gmail.com)


