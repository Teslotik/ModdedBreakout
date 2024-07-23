package blocks;

import haxe.Timer;
import hxd.Key;
import h2d.Bitmap;

using Lambda;

class Main extends hxd.App {
    var game:Game = null;

    public function new() {
        super();
    }

    override private function init():Void {
        super.init();
        game = new Game(s2d);

        engine.resize(game.width, game.height);

        // Base modification

        game.modifications.push({
            label: "base",
            priority: Normal,
            onEnable: modification -> {
                game.onUpdate.set("view", game -> {
                    if (game.state == Running) {
                        game.text.text = 'Scores: ${game.scores}';
                    } else if (game.state == Enabled) {
                        game.text.text = "Press Space";
                    } else {
                        game.text.text = 'Game over: ${game.scores}\nPress Space';
                    }
                });
                
                game.onUpdate.set("victory", game -> {
                    if (game.state == Running && (!game.entities.exists(e -> e.tag == "block") || !game.entities.exists(e -> e.tag == "ball"))) game.finish();
                });
                
                game.generators.push({
                    priority: Normal,
                    onGenerate: () -> {
                        // Placing blocks
                        var spacing = 5;
                        var cols = Std.int((game.width + spacing) / (48 + spacing));
                        for (i in 0...50) {
                            var block = game.create("block-normal");
                            // 48 x 12 - size of the block in the atlas
                            block.bitmap.x = (i % cols) * (48 + spacing);
                            block.bitmap.y = Std.int(i / cols) * (12 + spacing);
                        }

                        // Placing platform
                        var platform = game.create("platform-normal");
                        platform.bitmap.x = 100;
                        platform.bitmap.y = 300;

                        // Placing ball
                        var ball = game.create("ball-normal");
                        ball.bitmap.x = 100;
                        ball.bitmap.y = 200;
                    }
                });
                
                game.blockRegistry.set("block-normal", () -> {
                    tag: "block",
                    scores: 1,
                    bitmap: new Bitmap(game.atlas.sub(0, 0, 48, 12)),
                    onCollide: (e, c, dx, dy) -> game.destroy(e)
                });
                
                game.platformRegistry.set("platform-normal", () -> {
                    tag: "platform",
                    bitmap: new Bitmap(game.atlas.sub(0, 14, 16, 4)),
                    onInput: (entity, action, dt) -> {
                        if (action == Left) {
                            entity.bitmap.x -= game.platformSpeed * dt;
                        } else if (action == Right) {
                            entity.bitmap.x += game.platformSpeed * dt;
                        }
                        return true;
                    },
                    onCollide: (e, c, dx, dy) -> {}
                });
                game.ballRegistry.set("ball-normal", () -> {
                    tag: "ball",
                    // Yeah, I know, need to be normalized
                    // "feature" for now
                    velY: -game.ballSpeed,
                    velX: (Math.random() * 2 - 1) * game.ballSpeed,
                	bitmap: new Bitmap(game.atlas.sub(0, 20, 8, 8)),
                });
            },
            onDisable: modification -> {
                game.blockRegistry.remove("block-normal");
                game.blockRegistry.remove("platform-normal");
                game.blockRegistry.remove("ball-normal");
            }
        });

        game.modifications.push({
            label: "fireworks",
            priority: Normal,
            onEnable: modification -> {
                game.generators.push({
                    priority: Low,
                    onGenerate: () -> {
                        for (entity in game.entities) {
                            if (entity.tag != "block") continue;
                            if (Math.random() < 0.3) {
                                var explosive = game.replace(entity, "block-explosive");
                                explosive.bitmap.x = entity.bitmap.x;
                                explosive.bitmap.y = entity.bitmap.y;
                            } else if (Math.random() < 0.4) {
                                var buckshot = game.replace(entity, "block-doping");
                                buckshot.bitmap.x = entity.bitmap.x;
                                buckshot.bitmap.y = entity.bitmap.y;
                            } else if (Math.random() < 0.9) {
                                var buckshot = game.replace(entity, "block-buckshot");
                                buckshot.bitmap.x = entity.bitmap.x;
                                buckshot.bitmap.y = entity.bitmap.y;
                            } else if (Math.random() < 0.9) {
                                var clones = game.replace(entity, "block-clones");
                                clones.bitmap.x = entity.bitmap.x;
                                clones.bitmap.y = entity.bitmap.y;
                            }
                        }
                    }
                });

                game.blockRegistry.set("block-explosive", () -> {
                    tag: "block",
                    scores: 15,
                    bitmap: new Bitmap(game.atlas.sub(48, 0, 48, 12)),
                    onCollide: (entity, collider, dx, dy) -> {
                        game.explode(entity.bitmap.x + entity.bitmap.tile.width / 2, entity.bitmap.y + entity.bitmap.tile.height / 2);
                        game.destroy(entity);
                    }
                });
                
                game.blockRegistry.set("block-buckshot", () -> {
                    tag: "block",
                    scores: 5,
                    bitmap: new Bitmap(game.atlas.sub(144, 0, 48, 12)),
                    onCollide: (entity, collider, dx, dy) -> {
                        for (i in 0...2) {
                            var ball = game.create("ball-normal");
                            ball.bitmap.x = entity.bitmap.x;
                            ball.bitmap.y = entity.bitmap.y;
                            ball.velX = (Math.random() * 2 - 1) * game.ballSpeed;
                            ball.velY = (Math.random() * 2 - 1) * game.ballSpeed;
                        }
                        game.destroy(entity);
                    }
                });

                game.blockRegistry.set("block-doping", () -> {
                    tag: "block",
                    scores: 10,
                    bitmap: new Bitmap(game.atlas.sub(288, 0, 48, 12)),
                    onCollide: (entity, collider, dx, dy) -> {
                        game.entities.iter(e -> if (e.tag == "platform") game.replace(e, "platform-doping"));
                        Timer.delay(() -> game.entities.iter(e ->  if (e.tag == "platform") game.replace(e, "platform-normal")), 5000);
                        game.destroy(entity);
                    }
                });

                game.blockRegistry.set("block-clones", () -> {
                    tag: "block",
                    scores: 10,
                    bitmap: new Bitmap(game.atlas.sub(384, 0, 48, 12)),
                    onCollide: (entity, collider, dx, dy) -> {
                        var platform = game.create("platform-normal");
                        platform.bitmap.x = Math.random() * game.width;
                        platform.bitmap.y = Math.random() * 50 + game.height / 2;
                        game.destroy(entity);
                    }
                });

                game.platformRegistry.set("platform-doping", () -> {
                    tag: "platform",
                    bitmap: new Bitmap(game.atlas.sub(95, 14, 17, 4)),
                    onInput: (entity, action, dt) -> {
                        if (action == Left) {
                            entity.bitmap.x -= game.platformSpeed * 2 * dt;
                        } else if (action == Right) {
                            entity.bitmap.x += game.platformSpeed * 2 * dt;
                        }
                        return true;
                    },
                    onCollide: (e, c, dx, dy) -> {}
                });
            }
        });

        game.load().enable();
    }

    override function update(dt:Float) {
        if ((game.state == Enabled || game.state == Finished) && Key.isPressed(Key.SPACE)) {
            game.generate().run();
        }
        game.update(dt);
    }

    static function main() {
        hxd.Res.initEmbed();
        new Main();
    }
}