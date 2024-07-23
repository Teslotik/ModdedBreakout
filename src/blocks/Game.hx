package blocks;

import h2d.Text;
import h2d.Font;
import hxd.res.DefaultFont;
import h2d.Particles;
import blocks.Data.Priority;
import hscript.Interp;
import haxe.io.Path;
import sys.io.File;
import hxd.Key;
import hxd.Event;
import hxd.Res;
import h2d.Tile;
import h2d.Scene;
import blocks.Data.State;
import blocks.Data.Modification;
import blocks.Data.Entity;
import blocks.Data.Generator;
import blocks.Data.Action;
import sys.FileSystem;
import hscript.Parser;

using Lambda;

class Game {
    // Registry
    public var blockRegistry(default, null):Map<String, Void->Entity> = [];
    public var platformRegistry(default, null):Map<String, Void->Entity> = [];
    public var ballRegistry(default, null):Map<String, Void->Entity> = [];
    
    // Data
    public var entities = new Array<Entity>();
    public var modifications = new Array<Modification>();
    public var generators = new Array<Generator>();

    // Pipeline
    public var onLoad(default, null):Map<String, Game->Void> = [];
    public var onEnable(default, null):Map<String, Game->Void> = [];
    public var onDisable(default, null):Map<String, Game->Void> = [];
    public var onRun(default, null):Map<String, Game->Void> = [];
    public var onFinish(default, null):Map<String, Game->Void> = [];
    public var onUpdate(default, null):Map<String, Game->Void> = [];
    public var onGenerate(default, null):Map<String, Game->Void> = [];
    
    // State
    public var state(default, null):Null<State> = null;
    public var text(default, null):Text = null;
    public var scores = 0;

    // Resources
    public var atlas(default, null):Tile = null;
    public var font(default, null):Font = null;

    // Local
    public var s2d(default, null):Scene = null;
    public var delay(default, null) = new List<Void->Void>(); // will be handled in the next update cycle

    // Default parameters
    public final width = 640;
    public final height = 480;
    public final platformSpeed = 200.0;
    public final ballSpeed = 80.0;

    public function new(s2d:Scene) {
        this.s2d = s2d;
        atlas = Res.Atlas.toTile();
        font = DefaultFont.get();

        text = new Text(font);
        text.text = "Scores: 0";
        text.textAlign = Center;
        text.textColor = 0xFFA0A0A0;
        text.x = width / 2;
        text.y = height / 2;
        s2d.addChild(text);
    }
    
    // Lifecycle
    
    public function load() {
        if (state != null) throw "State must be 'null' to load the game";
        // @todo
        /*
        var mods = getDirectory("mods");
        if (!FileSystem.exists(mods)) {
            trace("[Warning] Mods folder doesn't exists");
        } else {
            for (filename in FileSystem.readDirectory(mods)) {
                var file = File.getContent(Path.join([mods, filename]));
                var parser = new Parser();
                parser.allowTypes = true;
                var program = parser.parseString(file);
                var interp = new Interp();
                interp.variables.set("Math", Math);
                interp.variables.set("game", this);
                var data = interp.execute(program);
                trace(file);
                trace(data);
                // trace(interp.variables.get("label"));
                // trace(interp.expr(parser.parseString("label")));

                modifications.push({
                    label: interp.expr(parser.parseString("label")),
                    // priority: interp.expr(parser.parseString("priority")) ?? Normal,
                    priority: Normal,
                    onEnable: mod -> interp.expr(parser.parseString("onEnable()")),
                    onDisable: mod -> interp.expr(parser.parseString("onDisable()"))
                });
            }
        }
        */

        modifications.sort((a, b) -> b.priority - a.priority);
        for (item in onLoad) item(this);
        state = Loaded;
        return this;
    }

    public function enable() {
        if (state != Loaded) throw "State must be 'Loaded' to enable the game";
        for (modification in modifications) {
            try {
                modification?.onEnable(modification);
            } catch (e) {
                trace('[Warning] Failed to enable modification: ${modification.label}');
            }
        }
        for (item in onEnable) item(this);
        state = Enabled;
        return this;
    }
    
    public function disable() {
        if (state == Loaded) throw "State musn\'t be 'Loaded' to disable the game";
        for (modification in modifications) {
            try {
                modification?.onDisable(modification);
            } catch (e) {
                trace('[Warning] Failed to disable modification: ${modification.label}');
            }
        }
        for (entity in entities) s2d.removeChild(entity.bitmap);
        entities = [];
        for (item in onDisable) item(this);
        state = Disabled;
        return this;
    }

    public function generate() {
        if (state != Enabled && state != Finished) throw "State must be 'Enabled' or 'Finished' to generate the game";
        generators.sort((a, b) -> b.priority - a.priority);
        for (generator in generators) {
            try {
                generator.onGenerate();
            } catch (e) {
                trace('[Warning] Generator failed');
            }
        }
        for (item in onGenerate) item(this);
        state = Generated;
        return this;
    }

    public function run() {
        if (state != Generated) throw "State must be 'Generated' to run the game";
        scores = 0;
        for (item in onRun) item(this);
        state = Running;
        return this;
    }

    public function finish() {
        if (state != Running) throw "State must be 'Running' to finish the game";
        for (entity in entities) destroy(entity);
        for (item in onFinish) item(this);
        state = Finished;
        return this;
    }

    public function update(dt:Float) {
        // Handling delay
        for (item in delay) item();
        delay.clear();
        
        if (state != Running) {
            for (item in onUpdate) item(this);
            return this;
        }

        // Updating input
        for (entity in entities) {
            if (!entity.isActive) continue;
            if (Key.isDown(Key.A) && !entity.onInput(entity, Left, dt)) break;
            if (Key.isDown(Key.D) && !entity.onInput(entity, Right, dt)) break;
            if (Key.isDown(Key.SPACE) && !entity.onInput(entity, Interact, dt)) break;
        }
        
        // Updating logic
        for (entity in entities) {
            if (!entity.isActive) continue;

            // Handling bounds
            if (entity.bitmap.x < 0 || entity.bitmap.y < 0 || entity.bitmap.x + entity.bitmap.tile.width > width || entity.bitmap.y + entity.bitmap.tile.height > height) {
                var dx = entity.bitmap.x < 0 ? -entity.bitmap.x : entity.bitmap.x + entity.bitmap.tile.width > width ? width - (entity.bitmap.x + entity.bitmap.tile.width): 0.0;
                var dy = entity.bitmap.y < 0 ? -entity.bitmap.y : entity.bitmap.y + entity.bitmap.tile.height > height ? height - (entity.bitmap.y + entity.bitmap.tile.height): 0.0;

                entity.bitmap.x += dx;
                entity.bitmap.y += dy;
                if (dx != 0) entity.velX *= -1;
                if (dy != 0) entity.velY *= -1;
                if (dy < 0) {
                    destroy(entity);
                }
                continue;
            }

            // Handling intersections
            for (collider in entities) {
                if (!collider.isActive) continue;
                if (collider == entity) continue;

                // Testing collisions
                if (collider.bitmap.x + collider.bitmap.tile.width < entity.bitmap.x || collider.bitmap.x > entity.bitmap.x + entity.bitmap.tile.width) continue;
                if (collider.bitmap.y + collider.bitmap.tile.height < entity.bitmap.y || collider.bitmap.y > entity.bitmap.y + entity.bitmap.tile.height) continue;

                // Calculating offset relative to velocity
                var dx = entity.velX < 0 ? collider.bitmap.x + collider.bitmap.tile.width - entity.bitmap.x : collider.bitmap.x - (entity.bitmap.x + entity.bitmap.tile.width);
                var dy = entity.velY < 0 ? collider.bitmap.y + collider.bitmap.tile.height - entity.bitmap.y : collider.bitmap.y - (entity.bitmap.y + entity.bitmap.tile.height);

                entity.onCollide(entity, collider, dx, dy);

                break;
            }
        }
        for (entity in entities) {
            if (!entity.isActive) continue;
            entity.onUpdate(dt);
        }
        
        // Updating physics
        for (entity in entities) {
            entity.bitmap.x += entity.velX * dt;
            entity.bitmap.y += entity.velY * dt;
        };

        for (item in onUpdate) item(this);
        return this;
    }

    // Utils

    public function getDirectory(label:String) {
        return Path.join([Sys.getCwd(), label]);
    }

    public function create(v:String, add = true) {
        var factory = blockRegistry.get(v) ?? platformRegistry.get(v) ?? ballRegistry.get(v);
        if (factory == null) {
            throw 'Entity $v doesn\'t exists in registry';
        }
        var entity = factory();
        entity.isActive ??= true;
        entity.velX ??= 0.0;
        entity.velY ??= 0.0;
        entity.scores ??= 0;
        entity.onInput ??= (entity, action, dt) -> true;
        entity.onUpdate ??= dt -> {};
        entity.onCollide ??= (entity, collider, dx, dy) -> {
            // Offsetting entity by minimal translation vector
            // and mirroring the velocity
            if (Math.abs(dx) < Math.abs(dy)) {
                entity.velX *= -1;
                entity.bitmap.x += dx;
            } else {
                entity.velY *= -1;
                entity.bitmap.y += dy;
            }
        }
        entity.onDestroy ??= entity -> {}
        entity.custom ??= [];
        if (add) {
            s2d.addChild(entity.bitmap);
            entities.push(entity);
        }
        return entity;
    }

    public function destroy(v:Entity) {
        scores += v.scores;
        delay.add(() -> {
            v.isActive = false;
            entities.remove(v);
            s2d.removeChild(v.bitmap);
            v.onDestroy(v);
        });
        return this;
    }

    public function replace(a:Entity, b:String) {
        var entity = create(b, false);
        entity.bitmap.x = a.bitmap.x;
        entity.bitmap.y = a.bitmap.y;
        a.isActive = false;
        delay.add(() -> {
            if (!entities.remove(a)) throw "Entity doesn't exists: " + a;
            s2d.removeChild(a.bitmap);
            s2d.addChild(entity.bitmap);
            entities.push(entity);
        });
        return entity;
    }

    public function explode(x:Float, y:Float) {
        var parts = new Particles(s2d);
        var group = parts.addGroup();
        parts.setPosition(x, y);

        group.size = 0.1;
        group.gravity = 1;
        group.life = 0.3;
        group.nparts = 100;
        group.emitMode = Point;
        group.emitLoop = false;
        group.speed = 1;
        parts.onEnd = () -> parts.remove();
    }
}