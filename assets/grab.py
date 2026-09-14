import asyncio
import os
from urllib.parse import urlparse
from playwright.async_api import async_playwright

OUTPUT_DIR = "loteria_assets"
os.makedirs(OUTPUT_DIR, exist_ok=True)

async def run():
    async with async_playwright() as p:
        # Launch visible browser so you can interact with the page
        browser = await p.chromium.launch(headless=False)
        page = await browser.new_page()

        async def handle_response(response):
            url = response.url
            # Filter for media assets from Google's static servers
            # if "google.com/logos/" in url and any(
            #     ext in url.lower() for ext in [".png", ".jpg", ".jpeg", ".webp", ".mp3", ".ogg", ".wav", ".json"]
            # ):
            if True:  # Capture all responses for demonstration purposes
                filename = os.path.basename(urlparse(url).path)
                if filename:
                    try:
                        data = await response.body()
                        filepath = os.path.join(OUTPUT_DIR, filename)
                        with open(filepath, "wb") as f:
                            f.write(data)
                        print(f"Captured: {filename}")
                    except Exception:
                        pass

        page.on("response", handle_response)

        print("Opening Loteria... Please click 'Play' in the browser window once it loads!")
        await page.goto("https://doodles.google/doodle/celebrating-loteria/", wait_until="domcontentloaded")
        
        # Keep window open for 300 seconds to allow clicking into a game round
        # await page.wait_for_timeout(300000)
        # await browser.close()
        try:
            print("Capturing assets... Press Ctrl+C when finished.")
            await asyncio.Event().wait()  # Keeps running indefinitely
        except (KeyboardInterrupt, asyncio.CancelledError):
            print("\nStopping capture...")
        finally:
            await browser.close()        

    print(f"\nFinished! Check ./{OUTPUT_DIR} for captured assets.")

asyncio.run(run())